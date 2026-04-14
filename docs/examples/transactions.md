# Transactions

Wrap multiple steps in a database transaction. If any step adds an error or raises an exception, the transaction is rolled back.

## Configuration

Set the transaction class either globally or per-operation:

```ruby
# Global
Opera::Operation::Config.configure do |config|
  config.transaction_class = ActiveRecord::Base
  config.transaction_method = :transaction     # default
  config.transaction_options = { requires_new: true }  # optional
end

# Per-operation
class MyOperation < Opera::Operation::Base
  configure do |config|
    config.transaction_class = Profile
  end
end
```

## Failing transaction

When a step inside a transaction fails, the entire transaction is rolled back:

```ruby
class Profile::Create < Opera::Operation::Base
  configure do |config|
    config.transaction_class = Profile
  end

  context do
    attr_accessor :profile
  end

  dependencies do
    attr_reader :current_account, :mailer
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
    self.profile = current_account.profiles.create(params)
  end

  def update
    profile.update(example_attr: :Example)
  end

  def send_email
    return true unless mailer

    mailer.send_mail(profile: profile)
  end

  def output
    result.output = { model: profile }
  end
end
```

### Example with non-existing attribute

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  mailer: MyMailer,
  current_account: Account.find(1)
})

D, [2020-08-14T16:13:30.946466 #2504] DEBUG -- :   Account Load (0.5ms)  SELECT  "accounts".* FROM "accounts" WHERE "accounts"."deleted_at" IS NULL AND "accounts"."id" = $1 LIMIT $2  [["id", 1], ["LIMIT", 1]]
D, [2020-08-14T16:13:30.960254 #2504] DEBUG -- :    (0.2ms)  BEGIN
D, [2020-08-14T16:13:30.983981 #2504] DEBUG -- :   SQL (0.7ms)  INSERT INTO "profiles" ("first_name", "last_name", "created_at", "updated_at", "account_id") VALUES ($1, $2, $3, $4, $5) RETURNING "id"  [["first_name", "foo"], ["last_name", "bar"], ["created_at", "2020-08-14 16:13:30.982289"], ["updated_at", "2020-08-14 16:13:30.982289"], ["account_id", 1]]
D, [2020-08-14T16:13:30.986233 #2504] DEBUG -- :    (0.2ms)  ROLLBACK
D, [2020-08-14T16:13:30.988231 #2504] DEBUG -- :    unknown attribute 'example_attr' for Profile. (ActiveModel::UnknownAttributeError)
```

## Passing transaction

```ruby
class Profile::Create < Opera::Operation::Base
  configure do |config|
    config.transaction_class = Profile
  end

  context do
    attr_accessor :profile
  end

  dependencies do
    attr_reader :current_account, :mailer
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
    self.profile = current_account.profiles.create(params)
  end

  def update
    profile.update(updated_at: 1.day.ago)
  end

  def send_email
    return true unless mailer

    mailer.send_mail(profile: profile)
  end

  def output
    result.output = { model: profile }
  end
end
```

### Example with updating timestamp

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  mailer: MyMailer,
  current_account: Account.find(1)
})
D, [2020-08-17T12:10:44.842392 #2741] DEBUG -- :   Account Load (0.7ms)  SELECT  "accounts".* FROM "accounts" WHERE "accounts"."deleted_at" IS NULL AND "accounts"."id" = $1 LIMIT $2  [["id", 1], ["LIMIT", 1]]
D, [2020-08-17T12:10:44.856964 #2741] DEBUG -- :    (0.2ms)  BEGIN
D, [2020-08-17T12:10:44.881332 #2741] DEBUG -- :   SQL (0.7ms)  INSERT INTO "profiles" ("first_name", "last_name", "created_at", "updated_at", "account_id") VALUES ($1, $2, $3, $4, $5) RETURNING "id"  [["first_name", "foo"], ["last_name", "bar"], ["created_at", "2020-08-17 12:10:44.879684"], ["updated_at", "2020-08-17 12:10:44.879684"], ["account_id", 1]]
D, [2020-08-17T12:10:44.886168 #2741] DEBUG -- :   SQL (0.6ms)  UPDATE "profiles" SET "updated_at" = $1 WHERE "profiles"."id" = $2  [["updated_at", "2020-08-16 12:10:44.883164"], ["id", 47]]
D, [2020-08-17T12:10:44.898132 #2741] DEBUG -- :    (10.3ms)  COMMIT
#<Opera::Operation::Result:0x0000556528f29058 @errors={}, @information={}, @executions=[:profile_schema, :create, :update, :send_email, :output], @output={:model=>#<Profile id: 47, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: "bar", created_at: "2020-08-17 12:10:44", updated_at: "2020-08-16 12:10:44", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```

## Using finish! inside a transaction

Calling `finish!` inside a transaction stops execution without rolling back -- the transaction commits successfully:

```ruby
class Profile::Create < Opera::Operation::Base
  context do
    attr_accessor :profile
  end

  dependencies do
    attr_reader :current_account, :mailer
  end

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
    self.profile = current_account.profiles.build(params)
    self.profile.force_name_validation = true
  end

  def create
    self.profile = profile.save
    finish!
  end

  def send_email
    return true unless mailer

    mailer.send_mail(profile: profile)
  end

  def output
    result.output(model: profile)
  end
end
```

### Call

```ruby
result = Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x007fc2c59a8460 @errors={}, @information={}, @executions=[:profile_schema, :build_record, :create]>
```
