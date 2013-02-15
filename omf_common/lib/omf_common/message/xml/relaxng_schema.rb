require 'singleton'

module OmfCommon
  class RelaxNGSchema
    include Singleton

    SCHEMA_FILE = "#{File.dirname(__FILE__)}/../../protocol/#{OmfCommon::PROTOCOL_VERSION}.rng"

    def initialize
      @rng = File.read(SCHEMA_FILE)
    end

    def validate(document)
      Nokogiri::XML::RelaxNG(@rng).validate(document)
    end
  end
end
