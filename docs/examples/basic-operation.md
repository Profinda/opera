# Basic Operation

A simple operation that validates input, creates a record, sends an email, and returns output.

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

## Call with valid parameters

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  mailer: MyMailer,
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x0000561636dced60 @errors={}, @information={}, @executions=[:profile_schema, :create, :send_email, :output], @output={:model=>#<Profile id: 30, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: "bar", created_at: "2020-08-14 16:04:08", updated_at: "2020-08-14 16:04:08", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```

## Call with INVALID parameters - missing first_name

```ruby
Profile::Create.call(params: {
  last_name: :bar
}, dependencies: {
  mailer: MyMailer,
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x0000562d3f635390 @errors={:first_name=>["is missing"]}, @information={}, @executions=[:profile_schema]>
```

## Call with MISSING dependencies

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  current_account: Account.find(1)
})

#<Opera::Operation::Result:0x007f87ba2c8f00 @errors={}, @information={}, @executions=[:profile_schema, :create, :send_email, :output], @output={:model=>#<Profile id: 33, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: "bar", created_at: "2019-01-03 12:04:25", updated_at: "2019-01-03 12:04:25", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```
