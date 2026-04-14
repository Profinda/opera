# Within

`within` wraps one or more steps with a method you define on the operation. The method must `yield` to execute the nested steps. If it does not yield, the nested steps are skipped. Normal break conditions (errors, `finish!`) still apply inside the block.

```ruby
class Profile::Create < Opera::Operation::Base
  context do
    attr_accessor :profile
  end

  dependencies do
    attr_reader :current_account
  end

  step :build

  within :read_from_replica do
    step :check_duplicate
    step :validate_quota
  end

  step :create
  step :output

  def build
    self.profile = current_account.profiles.build(params)
  end

  def check_duplicate
    result.add_error(:base, 'already exists') if Profile.exists?(email: params[:email])
  end

  def validate_quota
    result.add_error(:base, 'quota exceeded') if current_account.profiles.count >= 100
  end

  def create
    profile.save!
  end

  def output
    result.output = { model: profile }
  end

  private

  def read_from_replica(&block)
    ActiveRecord::Base.connected_to(role: :reading, &block)
  end
end
```

## Inline usage

The wrapper method can also be used inline inside any step method when you need the wrapper for only part of that method's logic:

```ruby
def some_step
  value = read_from_replica { Profile.count }
  result.output = { count: value }
end

private

def read_from_replica(&block)
  ActiveRecord::Base.connected_to(role: :reading, &block)
end
```

## Mixing step and operation inside within

`within` can wrap any combination of `step` and `operation` instructions. All of them execute inside the wrapper, and their outputs are available in context afterwards as usual.

```ruby
class Profile::Create < Opera::Operation::Base
  context do
    attr_accessor :profile
  end

  dependencies do
    attr_reader :current_account, :quota_checker
  end

  within :read_from_replica do
    step :check_duplicate
    operation :fetch_quota
  end

  step :create
  step :output

  def check_duplicate
    result.add_error(:base, 'already exists') if Profile.exists?(email: params[:email])
  end

  def fetch_quota
    quota_checker.call(params: params)
  end

  def create
    self.profile = current_account.profiles.create(params)
  end

  def output
    result.output = { model: profile, quota: context[:fetch_quota_output] }
  end

  private

  def read_from_replica(&block)
    ActiveRecord::Base.connected_to(role: :reading, &block)
  end
end
```

## Nesting within inside a transaction

`within` can be placed inside a `transaction` block alongside other instructions. If any step or operation inside `within` fails, the error propagates up and the transaction is rolled back as normal.

```ruby
class Profile::Create < Opera::Operation::Base
  configure do |config|
    config.transaction_class = ActiveRecord::Base
  end

  context do
    attr_accessor :profile
  end

  dependencies do
    attr_reader :current_account, :quota_checker, :audit_logger
  end

  transaction do
    within :read_from_replica do
      step :check_duplicate
      operation :fetch_quota
    end
    operation :write_audit_log
  end

  step :output

  def check_duplicate
    result.add_error(:base, 'already exists') if Profile.exists?(email: params[:email])
  end

  def fetch_quota
    quota_checker.call(params: params)
  end

  def write_audit_log
    audit_logger.call(params: params)
  end

  def output
    result.output = { quota: context[:fetch_quota_output] }
  end

  private

  def read_from_replica(&block)
    ActiveRecord::Base.connected_to(role: :reading, &block)
  end
end
```
