require "omf_common"
require 'omf_ec/backward/dsl'
require 'omf_ec/backward/group'
require "omf_ec/version"
require "omf_ec/experiment"
require "omf_ec/group"
require "omf_ec/group_context"
require "omf_ec/net_context"
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
