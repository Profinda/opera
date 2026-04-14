# Finish If

`finish_if` evaluates a method and stops execution (successfully) if the method returns a truthy value. Subsequent steps are skipped, but the operation is considered successful.

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
  finish_if :profile_create_only
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

  def create
    self.profile = current_account.profiles.create(params)
  end

  def profile_create_only
    dependencies[:create_only].present?
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

## Example

```ruby
Profile::Create.call(params: {
  first_name: :foo,
  last_name: :bar
}, dependencies: {
  create_only: true,
  current_account: Account.find(1)
})
#<Opera::Operation::Result:0x007fd0248e5638 @errors={}, @information={}, @executions=[:profile_schema, :create, :profile_create_only], @output={}>
```
