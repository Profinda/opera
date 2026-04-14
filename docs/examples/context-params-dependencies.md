# Context, Params & Dependencies

Opera provides typed accessor blocks for managing state within an operation.

## context

Mutable hash for passing data between steps. Supports `attr_reader`, `attr_writer`, and `attr_accessor`.

```ruby
context do
  attr_accessor :profile
  attr_accessor :account, default: -> { Account.new }
  attr_reader :schema_output
end
```

- `attr_accessor` defines getter and setter methods that read/write to the `context` hash
- `attr_reader` defines only a getter
- `default` accepts a lambda, evaluated lazily on first access when the key is missing

```ruby
context do
  attr_accessor :profile, :account
end

step :fetch_profile
step :update_profile

def fetch_profile
  self.profile = ProfileFetcher.call  # sets context[:profile]
end

def update_profile
  profile.update!(name: 'John')  # reads profile from context[:profile]
end
```

## params

Immutable hash received in the `call` method. Only supports `attr_reader`.

```ruby
params do
  attr_reader :activity, :requester
end
```

## dependencies

Immutable hash received in the `call` method. Only supports `attr_reader`.

```ruby
dependencies do
  attr_reader :current_account, :mailer
end
```

## context_reader with defaults

Use `context_reader` to read step outputs from the context hash:

```ruby
context_reader :schema_output

validate :schema  # context = { schema_output: { id: 1 } }
step :do_something

def do_something
  puts schema_output  # outputs: { id: 1 }
end
```

Use `default` to provide a fallback value when the key is missing:

```ruby
context_reader :profile, default: -> { Profile.new }

step :fetch_profile
step :do_something

def fetch_profile
  return if App.http_disabled?

  context[:profile] = ProfileFetcher.call
end

def update_profile
  profile.name = 'John'
  profile.save!
end
```

## Best practices

**Good** -- Use `context_reader` for step outputs and shared state:

```ruby
context_reader :schema_output
```

**Bad** -- Don't use `context_reader` with `default` for transient objects that aren't stored in context:

```ruby
# BAD: suggests serializer is part of persistent state
context_reader :serializer, default: -> { ProfileSerializer.new }
```

**Better** -- Use private methods for transient dependencies:

```ruby
step :output

def output
  self.result = serializer.to_json({...})
end

private

def serializer
  ProfileSerializer.new
end
```
