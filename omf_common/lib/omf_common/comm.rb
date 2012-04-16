require 'omf_common/dsl/xmpp_blather'

module OmfCommon
  class Comm
    def initialize(pubsub_implementation)
      self.class.include("OmfCommon::DSL::#{pubsub_implementation}".constant)
    end
  end
end

