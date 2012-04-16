require "omf_common/core_ext/blather/dsl"
require "omf_common/core_ext/blather/dsl/pubsub"
require "omf_common/core_ext/blather/stanza/registration"

module OmfCommon
  module Comm
    module XMPP
      extend Blather::DSL

      class << self
        def run
        end

        def setup
        end

        def disconnect
        end

        def topic_create
        end

        def topic_subscribe
        end

        def topic_publish
        end

        def topic_unsubscribe
        end

        def topic_delete
        end
      end
    end
  end
end
