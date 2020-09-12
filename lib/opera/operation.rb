# frozen_string_literal: true

require 'dry-validation'

require 'pro_finda/operation/builder'
require 'pro_finda/operation/base'
require 'pro_finda/operation/executor'
require 'pro_finda/operation/result'
require 'pro_finda/operation/config'
require 'pro_finda/operation/instructions/executors/success'
require 'pro_finda/operation/instructions/executors/transaction'
require 'pro_finda/operation/instructions/executors/benchmark'
require 'pro_finda/operation/instructions/executors/validate'
require 'pro_finda/operation/instructions/executors/operation'
require 'pro_finda/operation/instructions/executors/operations'
require 'pro_finda/operation/instructions/executors/step'

module ProFinda
  module Operation
    class UnknownInstructionError < ProFinda::Error; end
  end
end
