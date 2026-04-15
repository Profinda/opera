# Success Blocks

Steps inside a `success` block continue executing even if they return `false`. Errors added inside a success block **do** stop execution of subsequent non-success steps. Use success blocks for side effects that shouldn't halt the pipeline on falsy returns (e.g., sending emails, logging).

```ruby
class Profile::Create < Opera::Operation::Base
  context do
    attr_accessor :profile
  end

  dependencies do
    attr_reader :current_account, :mailer
  end

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
    self.profile = current_account.profiles.create(params)
  end

  def update
    profile.update(updated_at: 1.day.ago)
  end

  # NOTE: We can add an error in this step and it won't break the execution
  def send_email
    result.add_error('mailer', 'Missing dependency')
    mailer&.send_mail(profile: profile)
  end

  def output
    result.output = { model: context[:profile] }
  end
end
```

## Example output

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  current_account: Account.find(1)
})
#<Opera::Operation::Result:0x007fd0248e5638 @errors={"mailer"=>["Missing dependency"]}, @information={}, @executions=[:profile_schema, :populate, :create, :update, :send_email, :output], @output={:model=>#<Profile id: 40, user_id: nil, linkedin_uid: nil, picture: nil, headline: nil, summary: nil, first_name: "foo", last_name: "bar", created_at: "2019-01-03 12:21:35", updated_at: "2019-01-02 12:21:35", agree_to_terms_and_conditions: nil, registration_status: "", account_id: 1, start_date: nil, supervisor_id: nil, picture_processing: false, statistics: {}, data: {}, notification_timestamps: {}, suggestions: {}, notification_settings: {}, contact_information: []>}>
```
