# Validations

Opera supports `Dry::Validation::Result` and `Opera::Operation::Result` as return types from validate steps. Validations accumulate errors -- all validations run even if earlier ones fail, so the caller gets all errors at once.

## Example with sanitizing parameters

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
      configure { config.input_processor = :sanitizer }

      required(:first_name).filled
    end.call(params)
  end

  def create
    self.profile = current_account.profiles.create(context[:profile_schema_output])
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

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  mailer: MyMailer,
  current_account: Account.find(1)
})

# NOTE: Last name is missing in output model
#<Opera::Operation::Result:0x000055e36a1fab78 @errors={}, @information={}, @executions=[:profile_schema, :create, :send_email, :output], @output={:model=>#<Profile id: 44, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: nil, created_at: "2020-08-17 11:07:08", updated_at: "2020-08-17 11:07:08", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```

## Example with old (ActiveModel) validations

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
    self.profile = current_account.profiles.build(params)
    self.profile.force_name_validation = true
  end

  def old_validation
    return true if profile.valid?

    result.add_information(missing_validations: "Please check dry validations")
    result.add_errors(profile.errors.messages)

    false
  end

  def create
    profile.save
  end

  def send_email
    mailer.send_mail(profile: profile)
  end

  def output
    result.output = { model: profile }
  end
end
```

### Call with valid parameters

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  mailer: MyMailer,
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x0000560ebc9e7a98 @errors={}, @information={}, @executions=[:profile_schema, :build_record, :old_validation, :create, :send_email, :output], @output={:model=>#<Profile id: 41, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: "bar", created_at: "2020-08-14 19:15:12", updated_at: "2020-08-14 19:15:12", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```

### Call with INVALID parameters

```ruby
Profile::Create.call(params: {
  first_name: :foo
}, dependencies: {
  mailer: MyMailer,
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x0000560ef76ba588 @errors={:last_name=>["can't be blank"]}, @information={:missing_validations=>"Please check dry validations"}, @executions=[:build_record, :old_validation]>
```
