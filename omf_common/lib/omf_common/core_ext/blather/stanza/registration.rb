require 'blather'

module Blather
  class Stanza
    class Registration < Iq
      def self.new(username, password)
        node = super :set
        Nokogiri::XML::Builder.with(node) do |xml|
          xml.query('xmlns' => 'jabber:iq:register') do
            xml.username username
            xml.password password
          end
        end
        node
      end
    end
  end
end
