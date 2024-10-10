require "bundler/setup"
require "opera"
require "pry"

class BasicLogger
  %i[error info warn debug log fatal].each do |name|
    define_method(name) do |*args|
      puts "[#{name.upcase}] #{args.join("\n").inspect}"
    end
  end
end

Opera::Operation::Config.configure do |config|
  config.reporter = BasicLogger.new
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
