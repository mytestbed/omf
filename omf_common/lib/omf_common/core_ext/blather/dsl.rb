module Blather
  module DSL
    def register(username, password, &block)
      stanza = Blather::Stanza::Registration.new(username, password)
      client.write_with_handler(stanza, &block)
    end
  end
end
