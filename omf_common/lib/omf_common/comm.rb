require 'omf_common/dsl/xmpp'

module OmfCommon
  # PubSub communication class, can be extended with different implementations
  class Comm
    attr_reader :instrument
    def initialize(pubsub_implementation, instrument)
      @instrument = instrument
      self.extend("OmfCommon::DSL::#{pubsub_implementation.to_s.camelize}".constantize)
    end
  end
end
