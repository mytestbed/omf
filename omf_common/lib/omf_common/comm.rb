require 'omf_common/dsl/xmpp_blather'

module OmfCommon
  class Comm
    def initialize(pubsub_implementation)
      self.extend("OmfCommon::DSL::#{pubsub_implementation.to_s.camelcase}".constant)
    end
  end
end
