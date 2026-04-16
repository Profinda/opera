# frozen_string_literal: true

# Performance benchmark for Opera operations.
#
# Exercises the full execution path: step dispatch, instruction iteration,
# context accessors, validate, transaction, success, finish_if, operation,
# operations, within, and always -- with nested inner operations and loops to
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

  step :processing_error

  always :output

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

  def processing_error
    result.add_error(:base, 'processing failed')
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
# Within operation — wraps steps and inner operations with a custom method
# ---------------------------------------------------------------------------
WithinOperation = Class.new(Opera::Operation::Base) do
  configure do |config|
    config.transaction_class = FakeTransaction
  end

  context do
    attr_accessor :log, default: -> { [] }
  end

  step :prepare

  within :with_connection do
    step :query_one
    step :query_two
    operation :fetch_leaf
  end

  transaction do
    within :with_lock do
      step :write_one
      step :write_two
    end
    step :write_three
  end

  step :output

  def prepare
    context[:counter] = 0
  end

  def query_one
    context[:counter] += 1
    log << :query_one
  end

  def query_two
    context[:counter] += 1
    log << :query_two
  end

  def fetch_leaf
    LeafOperation.call(params: { n: context[:counter] })
  end

  def write_one
    context[:counter] += 10
    log << :write_one
  end

  def write_two
    context[:counter] += 10
    log << :write_two
  end

  def write_three
    context[:counter] += 1
    log << :write_three
  end

  def output
    result.output = {
      counter: context[:counter],
      log: log,
      leaf: context[:fetch_leaf_output]
    }
  end

  def with_connection
    log << :connect
    yield
    log << :disconnect
  end

  def with_lock
    log << :lock
    yield
    log << :unlock
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
# Always operation — exercises always steps on both success and failure paths
# ---------------------------------------------------------------------------
AlwaysOperation = Class.new(Opera::Operation::Base) do
  context do
    attr_accessor :log, default: -> { [] }
  end

  step :prepare
  step :process
  always :audit
  always :cleanup

  def prepare
    log << :prepare
    context[:value] = params.fetch(:value, 0)
  end

  def process
    if params[:fail]
      result.add_error(:base, 'processing failed')
    else
      context[:value] *= 2
      log << :process
    end
  end

  def audit
    log << (result.success? ? :audit_success : :audit_failure)
    result.output = { value: context[:value], log: log, success: result.success?, failure: result.failure? }
  end

  def cleanup
    log << :cleanup
  end
end

# ---------------------------------------------------------------------------
# Benchmark
# ---------------------------------------------------------------------------
ITERATIONS = 1000
PARAMS = { name: 'benchmark', batch_size: 5 }.freeze
BATCH_PARAMS = { count: 5 }.freeze
VALIDATION_PARAMS = { first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com' }.freeze
WITHIN_PARAMS = {}.freeze
ALWAYS_SUCCESS_PARAMS = { value: 21 }.freeze
ALWAYS_FAILURE_PARAMS = { value: 21, fail: true }.freeze

# Warm up
3.times do
  ComplexOperation.call(params: PARAMS)
  BatchOperation.call(params: BATCH_PARAMS)
  ValidationOperation.call(params: VALIDATION_PARAMS)
  WithinOperation.call(params: WITHIN_PARAMS)
  AlwaysOperation.call(params: ALWAYS_SUCCESS_PARAMS)
  AlwaysOperation.call(params: ALWAYS_FAILURE_PARAMS)
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

  x.report('WithinOperation (within + tx):') do
    ITERATIONS.times { WithinOperation.call(params: WITHIN_PARAMS) }
  end

  x.report('LeafOperation (minimal):') do
    ITERATIONS.times { LeafOperation.call(params: { n: 42 }) }
  end

  x.report('AlwaysOperation (success path):') do
    ITERATIONS.times { AlwaysOperation.call(params: ALWAYS_SUCCESS_PARAMS) }
  end

  x.report('AlwaysOperation (failure path):') do
    ITERATIONS.times { AlwaysOperation.call(params: ALWAYS_FAILURE_PARAMS) }
  end

  # Total operations executed in ComplexOperation run:
  # 1 complex + 1 inner + 5 leaf = 7 operations per iteration
  # = 7000 total operation instantiations for ComplexOperation alone
  total_ops = ITERATIONS * 7
  puts "\nComplexOperation spawns ~#{total_ops} total operation instances across #{ITERATIONS} calls"
end
