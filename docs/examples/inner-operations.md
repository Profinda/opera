# Inner Operations

## Single operation

Use `operation` to call another Opera operation from within a step. The method must return an `Opera::Operation::Result`. If the inner operation fails, errors are propagated and execution stops. If it succeeds, its output is stored in context as `:<method_name>_output`.

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

### Example with inner operation doing the find

```ruby
Profile::Create.call(params: {
  id: 1
}, dependencies: {
  current_account: Account.find(1)
})
#<Opera::Operation::Result:0x007f99b25f0f20 @errors={}, @information={}, @executions=[:profile_schema, :find, :create, :output], @output={:model=>{:id=>1, :user_id=>1, :linkedin_uid=>nil, ...}}>
```

## Multiple operations

Use `operations` when a method returns an array of `Opera::Operation::Result` objects. If any of the inner operations fail, all their errors are collected and execution stops.

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

#<Opera::Operation::Result:0x0000564189f38c90 @errors={}, @information={}, @executions=[{:create_multiple=>[[:validate, :create], [:validate, :create], [:validate, :create], [:validate, :create]]}, :output], @output=[{:model=>"Profile 1"}, {:model=>"Profile 7"}, {:model=>"Profile 69"}, {:model=>"Profile 92"}]>
```
