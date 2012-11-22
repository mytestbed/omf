require "omf_common"
require 'omf_ec/backward/dsl'
require 'omf_ec/backward/group'
require 'omf_ec/backward/default_events'
require 'omf_ec/backward/core_ext/array'
require "omf_ec/version"
require "omf_ec/experiment"
require "omf_ec/group"
require "omf_ec/context"
require "omf_ec/dsl"

module OmfEc
  class << self
    # Experiment instance
    def experiment
      Experiment.instance
    end

    alias_method :exp, :experiment

    # Experiment's communicator instance
    def communicator
      Experiment.instance.comm
    end

    alias_method :comm, :communicator
  end
end
