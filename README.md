# Opera

[![Gem Version](https://badge.fury.io/rb/opera.svg)](https://badge.fury.io/rb/opera)
![Master](https://github.com/Profinda/opera/actions/workflows/release.yml/badge.svg?branch=master)

A lightweight DSL for building operations, services and interactions in Ruby. Zero runtime dependencies.

Opera gives developers a consistent way to structure business logic as a pipeline of steps -- validate, execute, handle errors -- with a declarative DSL at the top of each class that makes the flow immediately readable.

## Installation

Add to your Gemfile:

```ruby
gem 'opera'
```

Then run `bundle install`.

> Requires Ruby >= 3.1. For Ruby 2.x use Opera 0.2.x.

## Quick Start

```ruby
class Profile::Create < Opera::Operation::Base
  context do
    attr_accessor :profile
  end

  dependencies do
    attr_reader :current_account, :mailer
  end

  validate :profile_schema

  step :create
  step :send_email
  step :output

  def profile_schema
    Dry::Validation.Schema do
      required(:first_name).filled
    end.call(params)
  end

  def create
    self.profile = current_account.profiles.create(params)
  end

  def send_email
    mailer&.send_mail(profile: profile)
  end

  def output
    result.output = { model: profile }
  end
end
```

```ruby
result = Profile::Create.call(
  params: { first_name: "Jane", last_name: "Doe" },
  dependencies: { current_account: Account.find(1), mailer: MyMailer }
)

result.success?  # => true
result.output    # => { model: #<Profile ...> }
```

## Configuration

```ruby
Opera::Operation::Config.configure do |config|
  config.transaction_class = ActiveRecord::Base
  config.transaction_method = :transaction                          # default
  config.transaction_options = { requires_new: true }               # optional
  config.instrumentation_class = MyInstrumentationAdapter           # optional
  config.mode = :development                                        # or :production
  config.reporter = Rails.logger                                    # optional
end
```

Override per operation:

```ruby
class MyOperation < Opera::Operation::Base
  configure do |config|
    config.transaction_class = Profile
    config.reporter = Rollbar
  end
end
```

Setting `mode: :production` skips storing execution traces for lower memory usage.

## Instrumentation

To instrument operations, create an adapter inheriting from `Opera::Operation::Instrumentation::Base`:

```ruby
class MyInstrumentation < Opera::Operation::Instrumentation::Base
  def self.instrument(operation, name:, level:)
    # level is :operation or :step
    Datadog::Tracing.trace(name, service: :opera) { yield }
  end
end

Opera::Operation::Config.configure do |config|
  config.instrumentation_class = MyInstrumentation
end
```

## DSL Reference

| Instruction                               | Description                                                                                                                                                                                                                                                                                       |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `step :method`                            | Executes a method. Returns falsy to stop execution.                                                                                                                                                                                                                                               |
| `validate :method`                        | Executes a method that must return `Dry::Validation::Result` or `Opera::Operation::Result`. Errors are accumulated -- all validations run even if some fail.                                                                                                                                      |
| `transaction do ... end`                  | Wraps steps in a database transaction. Rolls back on error.                                                                                                                                                                                                                                       |
| `success :method` or `success do ... end` | Like `step`, but a falsy return does **not** stop execution. Use for side effects.                                                                                                                                                                                                                |
| `finish_if :method`                       | Stops execution (successfully) if the method returns truthy.                                                                                                                                                                                                                                      |
| `operation :method`                       | Calls an inner operation. Must return `Opera::Operation::Result`. Propagates errors on failure. Output stored in `context[:<method>_output]`.                                                                                                                                                     |
| `operations :method`                      | Like `operation`, but the method must return an array of `Opera::Operation::Result`.                                                                                                                                                                                                              |
| `within :method do ... end`               | Wraps nested steps with a custom method that must `yield`. If it doesn't yield, nested steps are skipped.                                                                                                                                                                                         |
| `always :method`                          | Executes a step unconditionally after all regular steps, even after a failure or an early finish. Must appear at the end of the operation — only other `always` steps may follow. Cannot be used inside blocks. Use `result.success?` / `result.failure?` inside the method to branch on outcome. |

### Combining instructions

```ruby
class MyOperation < Opera::Operation::Base
  validate :schema

  step :prepare
  finish_if :already_done?

  transaction do
    step :create
    step :update

    within :read_from_replica do
      step :check_duplicate
    end
  end

  success do
    step :send_notification
    step :log_audit
  end

  step :output
  always :audit_trail
end
```

## Result API

| Method                  | Returns   | Description                                                |
| ----------------------- | --------- | ---------------------------------------------------------- |
| `success?`              | `Boolean` | `true` if no errors                                        |
| `failure?`              | `Boolean` | `true` if any errors                                       |
| `output`                | `Object`  | The operation's return value                               |
| `output!`               | `Object`  | Returns output if success, raises `OutputError` if failure |
| `output=`               |           | Sets the output                                            |
| `errors`                | `Hash`    | Accumulated error messages                                 |
| `failures`              | `Hash`    | Alias for `errors`                                         |
| `information`           | `Hash`    | Developer-facing metadata                                  |
| `executions`            | `Array`   | Ordered list of executed steps (development mode only)     |
| `add_error(key, value)` |           | Adds a single error                                        |
| `add_errors(hash)`      |           | Merges multiple errors                                     |
| `add_information(hash)` |           | Merges metadata                                            |

```ruby
# Pre-set output (useful in specs)
Opera::Operation::Result.new(output: 'success')
```

## Operation Instance Methods

| Method         | Description                                          |
| -------------- | ---------------------------------------------------- |
| `context`      | Mutable `Hash` for passing data between steps        |
| `params`       | Immutable `Hash` received via `call`                 |
| `dependencies` | Immutable `Hash` received via `call`                 |
| `result`       | The `Opera::Operation::Result` instance              |
| `finish!`      | Halts step execution (operation is still successful) |

## Testing

When using Opera inside a Rails engine, configure the transaction class in your test helper:

```ruby
# spec_helper.rb or rails_helper.rb
Opera::Operation::Config.configure do |config|
  config.transaction_class = ActiveRecord::Base
end
```

## Examples

Detailed examples with full input/output are available in the [`docs/examples/`](docs/examples/) directory:

- [Basic Operation](docs/examples/basic-operation.md)
- [Validations](docs/examples/validations.md)
- [Transactions](docs/examples/transactions.md)
- [Success Blocks](docs/examples/success-blocks.md)
- [Finish If](docs/examples/finish-if.md)
- [Inner Operations](docs/examples/inner-operations.md)
- [Within](docs/examples/within.md)
- [Always](docs/examples/always.md)
- [Context, Params & Dependencies](docs/examples/context-params-dependencies.md)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/profinda/opera. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/profinda/opera/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
