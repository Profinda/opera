# Always

`always` runs a step unconditionally at the end of the operation pipeline, after all regular steps have run (or been skipped). Unlike a regular `step`, it is never skipped — not when a prior step adds an error, not when `finish!` or `finish_if` DSL is called.

## Placement rules

- `always` steps must appear **after all other instructions** at the top level of the operation.
- Once an `always` is declared, only further `always` steps may follow — any other instruction (`step`, `operation`, `transaction`, `within`, etc.) raises an `ArgumentError` at class load time.
- `always` **cannot** be used inside blocks (`transaction do`, `within do`, `success do`, `validate do`). Doing so raises an `ArgumentError` at class load time.

```ruby
# correct
step :a
step :b
always :c
always :d

# raises ArgumentError — step follows always
step :a
always :b
step :c

# raises ArgumentError — always inside a transaction block
transaction do
  step :a
  always :b  # not allowed here
end
```

## Basic usage

```ruby
class Order::Submit < Opera::Operation::Base
  context do
    attr_accessor :order
  end

  dependencies do
    attr_reader :current_account, :audit_logger
  end

  step :build
  step :charge
  step :send_confirmation
  always :audit_log

  def build
    self.order = current_account.orders.build(params)
  end

  def charge
    result.add_error(:base, 'card declined') unless order.charge!
  end

  def send_confirmation
    # only reached when charge succeeds
    OrderMailer.confirmation(order).deliver_later
  end

  def audit_log
    # always runs, regardless of whether charge succeeded or failed
    audit_logger.record(order: order, success: result.success?)
  end
end
```

## Inspecting result state inside an always step

`result.success?` and `result.failure?` reflect the state of the operation **at the point `always` runs** — i.e. after all regular steps have executed (or been skipped due to failure). This lets you branch on the final outcome:

```ruby
class Profile::Delete < Opera::Operation::Base
  context do
    attr_accessor :profile
  end

  dependencies do
    attr_reader :current_account, :notifier
  end

  step :find
  step :destroy
  always :notify

  def find
    self.profile = current_account.profiles.find(params[:id])
  end

  def destroy
    result.add_error(:base, 'cannot delete') unless profile.destroy
  end

  def notify
    if result.success?
      notifier.call(event: :deleted, profile_id: params[:id])
    else
      notifier.call(event: :delete_failed, profile_id: params[:id], errors: result.errors)
    end
  end
end
```

## Multiple always steps

Multiple `always` steps are allowed and run in the order they are declared in:

```ruby
class Report::Generate < Opera::Operation::Base
  dependencies do
    attr_reader :audit_logger, :metrics
  end

  step :fetch_data
  step :render
  always :record_audit
  always :record_metrics

  def fetch_data
    # ...
  end

  def render
    # ...
  end

  def record_audit
    audit_logger.call(success: result.success?, errors: result.errors)
  end

  def record_metrics
    metrics.increment(result.success? ? 'report.success' : 'report.failure')
  end
end
```

## Operation finishes early

### With finish_if

`finish_if` halts execution successfully when its method returns truthy — subsequent regular steps are skipped, but `always` steps still run. Inside the always step, `result.success?` returns `true` because no errors were added:

```ruby
class Import::Run < Opera::Operation::Base
  dependencies do
    attr_reader :audit_logger
  end

  step :check_preconditions
  finish_if :already_imported?
  step :import
  step :output
  always :record_attempt

  def check_preconditions
    # validate source data is present
  end

  def already_imported?
    Import.exists?(ref: params[:ref])
  end

  def import
    Import.create!(params)
  end

  def output
    result.output = { imported: true }
  end

  def record_attempt
    # called whether import ran, was skipped via finish_if, or failed
    audit_logger.call(ref: params[:ref], success: result.success?)
  end
end
```

### With finish!

Calling `finish!` inside a step halts execution immediately and marks the operation successful. `always` steps still run afterwards:

```ruby
class Profile::Upsert < Opera::Operation::Base
  context do
    attr_accessor :profile
  end

  dependencies do
    attr_reader :current_account, :audit_logger
  end

  step :find_existing
  step :update_existing
  step :create_new
  step :output
  always :audit_log

  def find_existing
    self.profile = current_account.profiles.find_by(email: params[:email])
  end

  def update_existing
    return unless profile

    profile.update!(params)
    finish!
  end

  def create_new
    self.profile = current_account.profiles.create!(params)
  end

  def output
    result.output = { model: profile }
  end

  def audit_log
    # runs whether the record was updated (finish! path), created, or failed
    audit_logger.record(profile: profile, success: result.success?)
  end
end
```

## Combining with DSL blocks

`always` cannot be placed inside `transaction`, `within` or `validate` blocks. Place it after those blocks at the top level:

```ruby
class Ledger::Transfer < Opera::Operation::Base
  configure do |config|
    config.transaction_class = ActiveRecord::Base
  end

  dependencies do
    attr_reader :audit_logger
  end

  transaction do
    step :debit
    step :credit
  end

  step :output
  always :record_attempt

  def debit
    result.add_error(:base, 'insufficient funds') unless account.debit(params[:amount])
  end

  def credit
    account.credit(params[:amount])
  end

  def output
    result.output = { transferred: params[:amount] }
  end

  def record_attempt
    # runs after the transaction (and rollback, if any) has settled.
    # result.success? / result.failure? reflect the final outcome.
    audit_logger.call(
      params: params,
      success: result.success?,
      errors: result.errors
    )
  end
end
```
