# frozen_string_literal: true

require 'opera/operation/builder'
require 'opera/operation/base'
require 'opera/operation/executor'
require 'opera/operation/result'
require 'opera/operation/config'
require 'opera/operation/instructions/executors/success'
require 'opera/operation/instructions/executors/transaction'
require 'opera/operation/instructions/executors/benchmark'
require 'opera/operation/instructions/executors/finish_if'
require 'opera/operation/instructions/executors/validate'
require 'opera/operation/instructions/executors/operation'
require 'opera/operation/instructions/executors/operations'
require 'opera/operation/instructions/executors/step'

module Opera
  module Operation
  end
end
