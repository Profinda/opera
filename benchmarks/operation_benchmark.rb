# frozen_string_literal: true

# Performance benchmark for Opera operations.
#
# Exercises the full execution path: step dispatch, instruction iteration,
# context accessors, validate, transaction, success, finish_if, operation,
# operations, and within -- with nested inner operations and loops to
# simulate realistic workloads.
#
# Usage:
#   ruby benchmarks/operation_benchmark.rb

require 'bundler/setup'
require 'benchmark'
require 'opera'

# ---------------------------------------------------------------------------
# Fake transaction class (no DB, just yields)
# ---------------------------------------------------------------------------
FakeTransaction = Class.new do
  def self.transaction
    yield
  end
end

Opera::Operation::Config.configure do |config|
  config.transaction_class = FakeTransaction
  config.mode = :production # skip execution traces, like real production
end

# ---------------------------------------------------------------------------
# Leaf operation — called many times from within loops
# ---------------------------------------------------------------------------
LeafOperation = Class.new(Opera::Operation::Base) do
  step :compute
  step :output

  def compute
    context[:value] = params.fetch(:n, 1) * 2
  end

  def output
    result.output = { value: context[:value] }
  end
end

# ---------------------------------------------------------------------------
# Inner operation — calls LeafOperation in a loop
# ---------------------------------------------------------------------------
InnerOperation = Class.new(Opera::Operation::Base) do
  context do
    attr_accessor :results
  end

  step :process_batch
  step :output

  def process_batch
    self.results = (1..params.fetch(:batch_size, 5)).map do |n|
      LeafOperation.call(params: { n: n })
    end
  end

  def output
    result.output = { batch: results.map(&:output) }
  end
end

# ---------------------------------------------------------------------------
# Validation-heavy operation
# ---------------------------------------------------------------------------
ValidationOperation = Class.new(Opera::Operation::Base) do
  validate :schema

  step :transform
  step :output

  def schema
    # Return a successful Opera::Operation::Result (simulates dry-validation)
    Opera::Operation::Result.new(output: params)
  end

  def transform
    context[:transformed] = params.transform_values { |v| v.to_s.upcase }
  end

  def output
    result.output = context[:transformed]
  end
end

# ---------------------------------------------------------------------------
# Complex operation — combines everything
# ---------------------------------------------------------------------------
ComplexOperation = Class.new(Opera::Operation::Base) do
  configure do |config|
    config.transaction_class = FakeTransaction
  end

  context do
    attr_accessor :profile, :batch_results, :validated
  end

  validate :schema

  step :prepare
  finish_if :skip_processing?

  transaction do
    step :create_record
    step :update_record
  end

  operation :run_inner

  within :with_timing do
    step :heavy_computation
  end

  success do
    step :notify
    step :log_audit
  end

  step :output

  def schema
    Opera::Operation::Result.new(output: params)
  end

  def prepare
    self.validated = context[:schema_output]
    context[:counter] = 0
  end

  def skip_processing?
    params[:skip] == true
  end

  def create_record
    self.profile = { id: rand(1000), name: validated[:name] }
  end

  def update_record
    profile[:updated_at] = Time.now.to_i
  end

  def run_inner
    InnerOperation.call(params: { batch_size: params.fetch(:batch_size, 5) })
  end

  def heavy_computation
    # Simulate CPU work: string operations in a loop
    50.times do |i|
      context[:counter] += i
      "operation-#{i}-#{context[:counter]}".hash
    end
  end

  def notify
    context[:notified] = true
  end

  def log_audit
    context[:audited] = true
  end

  def output
    result.output = {
      profile: profile,
      counter: context[:counter],
      batch: context[:run_inner_output]
    }
  end

  def with_timing
    yield
  end
end

# ---------------------------------------------------------------------------
# Operations (plural) consumer — calls multiple inner operations
# ---------------------------------------------------------------------------
BatchOperation = Class.new(Opera::Operation::Base) do
  operations :run_all
  step :output

  def run_all
    (1..params.fetch(:count, 3)).map do |n|
      LeafOperation.call(params: { n: n })
    end
  end

  def output
    result.output = context[:run_all_output]
  end
end

# ---------------------------------------------------------------------------
# Benchmark
# ---------------------------------------------------------------------------
ITERATIONS = 1000
PARAMS = { name: 'benchmark', batch_size: 5 }.freeze
BATCH_PARAMS = { count: 5 }.freeze
VALIDATION_PARAMS = { first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com' }.freeze

# Warm up
3.times do
  ComplexOperation.call(params: PARAMS)
  BatchOperation.call(params: BATCH_PARAMS)
  ValidationOperation.call(params: VALIDATION_PARAMS)
end

puts "Opera v#{Opera::VERSION} — #{ITERATIONS} iterations each"
puts "Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})"
puts '-' * 60

Benchmark.bm(35) do |x|
  x.report('ComplexOperation (nested + tx):') do
    ITERATIONS.times { ComplexOperation.call(params: PARAMS) }
  end

  x.report('BatchOperation (operations):') do
    ITERATIONS.times { BatchOperation.call(params: BATCH_PARAMS) }
  end

  x.report('ValidationOperation (validate):') do
    ITERATIONS.times { ValidationOperation.call(params: VALIDATION_PARAMS) }
  end

  x.report('LeafOperation (minimal):') do
    ITERATIONS.times { LeafOperation.call(params: { n: 42 }) }
  end

  # Total operations executed in ComplexOperation run:
  # 1 complex + 1 inner + 5 leaf = 7 operations per iteration
  # = 7000 total operation instantiations for ComplexOperation alone
  total_ops = ITERATIONS * 7
  puts "\nComplexOperation spawns ~#{total_ops} total operation instances across #{ITERATIONS} calls"
end
