# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in opera.gemspec
gemspec

gem 'rake', '~> 13.2'
gem 'rspec', '~> 3.13'

group :development do
  gem 'rubocop'
  gem 'rubocop-performance'
  gem 'rubocop-rake'
  gem 'rubocop-rspec'
end

group :test, :development do
  gem 'dry-validation'
  gem 'pry'
  gem 'pry-byebug', require: false, platforms: :ruby
end
