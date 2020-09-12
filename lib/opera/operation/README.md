# Opera::Operation

Simple DSL for services/interactions classes.

# Installation

```
gem install pro_finda-operation
```

or in Gemfile:

```
gem 'pro_finda-operation', path: 'vendor/pro_finda-operation'
```

# Configuration

```ruby
Opera::Operation::Config.configure do |config|
  config.transaction_class = ActiveRecord::Base
  config.transaction_method = :transaction
  config.reporter = if defined?(Rollbar) then Rollbar else Rails.logger
end

class A < Opera::Operation::Base

  configure do |config|
    config.transaction_class = Profile
    config.reporter = Rails.logger
  end

  success :populate

  operation :inner_operation

  validate :profile_schema

  transaction do
    step :create
    step :update
    step :destroy
  end

  validate do
    step :validate_object
    step :validate_relationships
  end

  benchmark do
    success :hal_sync
  end

  success do
    step :send_mail
    step :report_to_audit_log
  end

  step :output
end
```

# Specs

When using Opera::Operation inside an engine add the following
configuration to your spec_helper.rb or rails_helper.rb:

```
Opera::Operation::Config.configure do |config|
  config.transaction_class = ActiveRecord::Base
end
```

Without this extra configuration you will receive:
```
NoMethodError:
  undefined method `transaction' for nil:NilClass
```

# Debugging

When you want to easily debug exceptions you can add this
to your dummy.rb:

```
Rails.application.configure do
  config.x.reporter = Logger.new(STDERR)
end
```

This should display exceptions captured inside operations.

You can also do it in Opera::Operation configuration block:

```
Opera::Operation::Config.configure do |config|
  config.transaction_class = ActiveRecord::Base
  config.reporter = Logger.new(STDERR)
end
```

# Content
[Basic operation](#user-content-basic-operation)

[Example with sanitizing parameters](#user-content-example-with-sanitizing-parameters)

[Example operation with old validations](#user-content-example-operation-with-old-validations)

[Example with step that raises exception](#user-content-example-with-step-that-raises-exception)

[Failing transaction](#user-content-failing-transaction)

[Passing transaction](#user-content-passing-transaction)

[Benchmark](#user-content-benchmark)

[Success](#user-content-success)

[Inner Operation](#user-content-inner-operation)

[Inner Operations](#user-content-inner-operations)

# Usage examples

Some cases and example how to use new operations

## Basic operation

```ruby
class Profile::Create < Opera::Operation::Base
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
    context[:profile] = dependencies[:current_account].profiles.create(params)
  end

  def send_email
    dependencies[:mailer]&.send_mail(profile: context[:profile])
  end

  def output
    result.output = { model: context[:profile] }
  end
end
```

#### Call with valid parameters

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  mailer: ProfindaMailer,
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x0000561636dced60 @errors={}, @exceptions={}, @information={}, @executions=[:profile_schema, :create, :send_email, :output], @output={:model=>#<Profile id: 30, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: "bar", created_at: "2018-12-14 16:04:08", updated_at: "2018-12-14 16:04:08", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```

#### Call with INVALID parameters - missing first_name

```ruby
Profile::Create.call(params: {
  last_name: :bar
}, dependencies: {
  mailer: ProfindaMailer,
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x0000562d3f635390 @errors={:first_name=>["is missing"]}, @exceptions={}, @information={}, @executions=[:profile_schema]>
```

#### Call with MISSING dependencies

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x007f87ba2c8f00 @errors={}, @exceptions={}, @information={}, @executions=[:profile_schema, :create, :send_email, :output], @output={:model=>#<Profile id: 33, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: "bar", created_at: "2019-01-03 12:04:25", updated_at: "2019-01-03 12:04:25", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```

## Example with sanitizing parameters

```ruby
class Profile::Create < Opera::Operation::Base
  validate :profile_schema

  step :create
  step :send_email
  step :output

  def profile_schema
    Dry::Validation.Schema do
      configure { config.input_processor = :sanitizer }

      required(:first_name).filled
    end.call(params)
  end

  def create
    context[:profile] = dependencies[:current_account].profiles.create(context[:profile_schema_output])
  end

  def send_email
    return true unless dependencies[:mailer]
    dependencies[:mailer].send_mail(profile: context[:profile])
  end

  def output
    result.output = { model: context[:profile] }
  end
end
```

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  mailer: ProfindaMailer,
  current_account: Account.find(1)
})

# NOTE: Last name is missing in output model
#<Opera::Operation::Result:0x000055e36a1fab78 @errors={}, @exceptions={}, @information={}, @executions=[:profile_schema, :create, :send_email, :output], @output={:model=>#<Profile id: 44, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: nil, created_at: "2018-12-17 11:07:08", updated_at: "2018-12-17 11:07:08", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```

## Example operation with old validations

```ruby
class Profile::Create < Opera::Operation::Base
  validate :profile_schema

  step :build_record
  step :old_validation
  step :create
  step :send_email
  step :output

  def profile_schema
    Dry::Validation.Schema do
      required(:first_name).filled
    end.call(params)
  end

  def build_record
    context[:profile] = dependencies[:current_account].profiles.build(params)
    context[:profile].force_name_validation = true
  end

  def old_validation
    return true if context[:profile].valid?

    result.add_information(missing_validations: "Please check dry validations")
    result.add_errors(context[:profile].errors.messages)

    false
  end

  def create
    context[:profile].save
  end

  def send_email
    dependencies[:mailer].send_mail(profile: context[:profile])
  end

  def output
    result.output = { model: context[:profile] }
  end
end
```

#### Call with valid parameters

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  mailer: ProfindaMailer,
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x0000560ebc9e7a98 @errors={}, @exceptions={}, @information={}, @executions=[:profile_schema, :build_record, :old_validation, :create, :send_email, :output], @output={:model=>#<Profile id: 41, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: "bar", created_at: "2018-12-14 19:15:12", updated_at: "2018-12-14 19:15:12", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```

#### Call with INVALID parameters

```ruby
Profile::Create.call(params: {
  first_name: :foo
}, dependencies: {
  mailer: ProfindaMailer,
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x0000560ef76ba588 @errors={:last_name=>["can't be blank"]}, @exceptions={}, @information={:missing_validations=>"Please check dry validations"}, @executions=[:build_record, :old_validation]>
```

## Example with step that raises exception

```ruby
class Profile::Create < Opera::Operation::Base
  validate :profile_schema

  step :build_record
  step :exception
  step :create
  step :send_email
  step :output

  def profile_schema
    Dry::Validation.Schema do
      required(:first_name).filled
    end.call(params)
  end

  def build_record
    context[:profile] = dependencies[:current_account].profiles.build(params)
    context[:profile].force_name_validation = true
  end

  def exception
    raise StandardError, 'Example'
  end

  def create
    context[:profile] = context[:profile].save
  end

  def send_email
    return true unless dependencies[:mailer]

    dependencies[:mailer].send_mail(profile: context[:profile])
  end

  def output
    result.output(model: context[:profile])
  end
end
```
##### Call with step throwing exception
```ruby
result = Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x0000562ad0f897c8 @errors={}, @exceptions={"Profile::Create#exception"=>["Example"]}, @information={}, @executions=[:profile_schema, :build_record, :exception]>
```

## Example with step that finishes execution

```ruby
class Profile::Create < Opera::Operation::Base
  validate :profile_schema

  step :build_record
  step :create
  step :send_email
  step :output

  def profile_schema
    Dry::Validation.Schema do
      required(:first_name).filled
    end.call(params)
  end

  def build_record
    context[:profile] = dependencies[:current_account].profiles.build(params)
    context[:profile].force_name_validation = true
  end

  def create
    context[:profile] = context[:profile].save
    finish
  end

  def send_email
    return true unless dependencies[:mailer]

    dependencies[:mailer].send_mail(profile: context[:profile])
  end

  def output
    result.output(model: context[:profile])
  end
end
```
##### Call
```ruby
result = Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x007fc2c59a8460 @errors={}, @exceptions={}, @information={}, @executions=[:profile_schema, :build_record, :create]>
```

## Failing transaction

```ruby
class Profile::Create < Opera::Operation::Base
  configure do |config|
    config.transaction_class = Profile
  end

  validate :profile_schema

  transaction do
    step :create
    step :update
  end

  step :send_email
  step :output

  def profile_schema
    Dry::Validation.Schema do
      required(:first_name).filled
    end.call(params)
  end

  def create
    context[:profile] = dependencies[:current_account].profiles.create(params)
  end

  def update
    context[:profile].update(example_attr: :Example)
  end

  def send_email
    return true unless dependencies[:mailer]

    dependencies[:mailer].send_mail(profile: context[:profile])
  end

  def output
    result.output = { model: context[:profile] }
  end
end
```

#### Example with non-existing attribute

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  mailer: ProfindaMailer,
  current_account: Account.find(1)
})

D, [2018-12-14T16:13:30.946466 #2504] DEBUG -- :   Account Load (0.5ms)  SELECT  "accounts".* FROM "accounts" WHERE "accounts"."deleted_at" IS NULL AND "accounts"."id" = $1 LIMIT $2  [["id", 1], ["LIMIT", 1]]
D, [2018-12-14T16:13:30.960254 #2504] DEBUG -- :    (0.2ms)  BEGIN
D, [2018-12-14T16:13:30.983981 #2504] DEBUG -- :   SQL (0.7ms)  INSERT INTO "profiles" ("first_name", "last_name", "created_at", "updated_at", "account_id") VALUES ($1, $2, $3, $4, $5) RETURNING "id"  [["first_name", "foo"], ["last_name", "bar"], ["created_at", "2018-12-14 16:13:30.982289"], ["updated_at", "2018-12-14 16:13:30.982289"], ["account_id", 1]]
D, [2018-12-14T16:13:30.986233 #2504] DEBUG -- :    (0.2ms)  ROLLBACK
#<Opera::Operation::Result:0x00005650e89b7708 @errors={}, @exceptions={"Profile::Create#update"=>["unknown attribute 'example_attr' for Profile."], "Profile::Create#transaction"=>["Opera::Operation::Base::RollbackTransactionError"]}, @information={}, @executions=[:profile_schema, :create, :update]>
```

## Passing transaction

```ruby
class Profile::Create < Opera::Operation::Base
  configure do |config|
    config.transaction_class = Profile
  end

  validate :profile_schema

  transaction do
    step :create
    step :update
  end

  step :send_email
  step :output

  def profile_schema
    Dry::Validation.Schema do
      required(:first_name).filled
    end.call(params)
  end

  def create
    context[:profile] = dependencies[:current_account].profiles.create(params)
  end

  def update
    context[:profile].update(updated_at: 1.day.ago)
  end

  def send_email
    return true unless dependencies[:mailer]

    dependencies[:mailer].send_mail(profile: context[:profile])
  end

  def output
    result.output = { model: context[:profile] }
  end
end
```

#### Example with updating timestamp

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  mailer: ProfindaMailer,
  current_account: Account.find(1)
})
D, [2018-12-17T12:10:44.842392 #2741] DEBUG -- :   Account Load (0.7ms)  SELECT  "accounts".* FROM "accounts" WHERE "accounts"."deleted_at" IS NULL AND "accounts"."id" = $1 LIMIT $2  [["id", 1], ["LIMIT", 1]]
D, [2018-12-17T12:10:44.856964 #2741] DEBUG -- :    (0.2ms)  BEGIN
D, [2018-12-17T12:10:44.881332 #2741] DEBUG -- :   SQL (0.7ms)  INSERT INTO "profiles" ("first_name", "last_name", "created_at", "updated_at", "account_id") VALUES ($1, $2, $3, $4, $5) RETURNING "id"  [["first_name", "foo"], ["last_name", "bar"], ["created_at", "2018-12-17 12:10:44.879684"], ["updated_at", "2018-12-17 12:10:44.879684"], ["account_id", 1]]
D, [2018-12-17T12:10:44.886168 #2741] DEBUG -- :   SQL (0.6ms)  UPDATE "profiles" SET "updated_at" = $1 WHERE "profiles"."id" = $2  [["updated_at", "2018-12-16 12:10:44.883164"], ["id", 47]]
D, [2018-12-17T12:10:44.898132 #2741] DEBUG -- :    (10.3ms)  COMMIT
#<Opera::Operation::Result:0x0000556528f29058 @errors={}, @exceptions={}, @information={}, @executions=[:profile_schema, :create, :update, :send_email, :output], @output={:model=>#<Profile id: 47, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: "bar", created_at: "2018-12-17 12:10:44", updated_at: "2018-12-16 12:10:44", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```

## Benchmark

```ruby
class Profile::Create < Opera::Operation::Base
  validate :profile_schema

  step :create
  step :update

  benchmark do
    step :send_email
    step :output
  end

  def profile_schema
    Dry::Validation.Schema do
      required(:first_name).filled
    end.call(params)
  end

  def create
    context[:profile] = dependencies[:current_account].profiles.create(params)
  end

  def update
    context[:profile].update(updated_at: 1.day.ago)
  end

  def send_email
    return true unless dependencies[:mailer]

    dependencies[:mailer].send_mail(profile: context[:profile])
  end

  def output
    result.output = { model: context[:profile] }
  end
end
```

#### Example with information (real and total) from benchmark

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  current_account: Account.find(1)
})
#<Opera::Operation::Result:0x007ff414a01238 @errors={}, @exceptions={}, @information={:real=>1.800013706088066e-05, :total=>0.0}, @executions=[:profile_schema, :create, :update, :send_email, :output], @output={:model=>#<Profile id: 30, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: "bar", created_at: "2018-12-19 10:46:00", updated_at: "2018-12-18 10:46:00", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```

## Success

```ruby
class Profile::Create < Opera::Operation::Base
  validate :profile_schema

  success :populate

  step :create
  step :update

  success do
    step :send_email
    step :output
  end

  def profile_schema
    Dry::Validation.Schema do
      required(:first_name).filled
    end.call(params)
  end

  def populate
    context[:attributes] = {}
    context[:valid] = false
  end

  def create
    context[:profile] = dependencies[:current_account].profiles.create(params)
  end

  def update
    context[:profile].update(updated_at: 1.day.ago)
  end

  # NOTE: We can add an error in this step and it won't break the execution
  def send_email
    result.add_error('mailer', 'Missing dependency')
    dependencies[:mailer]&.send_mail(profile: context[:profile])
  end

  def output
    result.output = { model: context[:profile] }
  end
end
```

#### Example with information (real and total) from benchmark

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  current_account: Account.find(1)
})
#<Opera::Operation::Result:0x007fd0248e5638 @errors={"mailer"=>["Missing dependency"]}, @exceptions={}, @information={}, @executions=[:profile_schema, :populate, :create, :update, :send_email, :output], @output={:model=>#<Profile id: 40, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: "bar", created_at: "2019-01-03 12:21:35", updated_at: "2019-01-02 12:21:35", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```

## Inner Operation

```ruby
class Profile::Find < Opera::Operation::Base
  step :find

  def find
    result.output = Profile.find(params[:id])
  end
end

class Profile::Create < Opera::Operation::Base
  validate :profile_schema

  operation :find

  step :create

  step :output

  def profile_schema
    Dry::Validation.Schema do
      optional(:id).filled
    end.call(params)
  end

  def find
    Profile::Find.call(params: params, dependencies: dependencies)
  end

  def create
    return if context[:find_output]
    puts 'not found'
  end

  def output
    result.output = { model: context[:find_output] }
  end
end
```

#### Example with inner operation doing the find

```ruby
Profile::Create.call(params: {
  id: 1
}, dependencies: {
  current_account: Account.find(1)
})
#<Opera::Operation::Result:0x007f99b25f0f20 @errors={}, @exceptions={}, @information={}, @executions=[:profile_schema, :find, :create, :output], @output={:model=>{:id=>1, :user_id=>1, :linkedin_uid=>nil, ...}}>
```

## Inner Operations
Expects that method returns array of `Opera::Operation::Result`

```ruby
class Profile::Create < Opera::Operation::Base
  step :validate
  step :create

  def validate; end

  def create
    result.output = { model: "Profile #{Kernel.rand(100)}" }
  end
end

class Profile::CreateMultiple < Opera::Operation::Base
  operations :create_multiple

  step :output

  def create_multiple
    (0..params[:number]).map do
      Profile::Create.call
    end
  end

  def output
    result.output = context[:create_multiple_output]
  end
end
```

```ruby
Profile::CreateMultiple.call(params: { number: 3 })

#<Opera::Operation::Result:0x0000564189f38c90 @errors={}, @exceptions={}, @information={}, @executions=[{:create_multiple=>[[:validate, :create], [:validate, :create], [:validate, :create], [:validate, :create]]}, :output], @output=[{:model=>"Profile 1"}, {:model=>"Profile 7"}, {:model=>"Profile 69"}, {:model=>"Profile 92"}]>
```

## Opera::Operation::Result - Instance Methods

Sometimes it may be useful to be able to create an instance of the `Result` with preset `output`.
It can be handy especially in specs. Then just include it in the initializer:

```
Opera::Operation::Result.new(output: 'success')
```

>
    - success? - [true, false] - Return true if no errors and no exceptions
    - failure? - [true, false] - Return true if any error or exception
    - output   - [Anything]    - Return Anything
    - output=(Anything)        - Sets content of operation output
    - add_error(key, value)    - Adds new error message
    - add_errors(Hash)         - Adds multiple error messages
    - add_exception(method, message, classname: nil) - Adds new exception
    - add_exceptions(Hash)     - Adds multiple exceptions
    - add_information(Hash)    - Adss new information - Useful informations for developers

## Opera::Operation::Base - Class Methods
>
    - step(Symbol)             - single instruction
      - return [Truthly]       - continue operation execution
      - return [False]         - stops operation execution
      - raise Exception        - exception gets captured and stops operation execution
    - operation(Symbol)        - single instruction - requires to return Opera::Operation::Result object
      - return [Opera::Operation::Result] - stops operation STEPS execution if any error, exception
    - validate(Symbol)         - single dry-validations - requires to return Dry::Validation::Result object
      - return [Dry::Validation::Result] - stops operation STEPS execution if any error but continue with other validations
    - transaction(*Symbols)    - list of instructions to be wrapped in transaction
      - return [Truthly]       - continue operation execution
      - return [False|Exception] - stops operation execution and breaks transaction/do rollback
    - call(params: Hash, dependencies: Hash?)
      - return [Opera::Operation::Result] - never raises an exception

## Opera::Operation::Base - Instance Methods
>
    - context [Hash]          - used to pass information between steps - only for internal usage
    - params [Hash]           - immutable and received in call method
    - dependencies [Hash]     - immutable and received in call method
    - finish                  - this method interrupts the execution of steps after is invoked
