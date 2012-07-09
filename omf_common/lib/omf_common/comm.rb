require 'omf_common/dsl/xmpp_blather'

module OmfCommon
  # PubSub communication class, can be extended with different implementations
  class Comm
    def initialize(pubsub_implementation)
      self.extend("OmfCommon::DSL::#{pubsub_implementation.to_s.camelize}".constantize)
    end
  end
end
