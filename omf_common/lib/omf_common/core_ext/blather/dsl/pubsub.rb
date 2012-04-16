module Blather
  module DSL
    class PubSub
      def create_with_configuration(node, configuration, host = nil)
        stanza = Stanza::PubSub::Create.new(:set, send_to(host), node)
        stanza.configure_node << configure
        request(stanza) { |n| yield n if block_given? }
      end
    end
  end
end
