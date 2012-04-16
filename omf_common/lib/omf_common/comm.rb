require 'omf_common/dsl/xmpp'

module OmfCommon
  class Comm
    def initialize(pubsub_implementation)
      self.class.include("OmfCommon::Comm::#{pubsub_implementation}".constant)
    end
  end
end

