require 'singleton'

module OmfCommon
  class RelaxNGSchema
    include Singleton

    SCHEMA_FILE = "#{File.dirname(__FILE__)}/protocol/#{OmfCommon::PROTOCOL_VERSION}.rng"

    attr_accessor :schema

    def initialize
      File.open(SCHEMA_FILE) do |f|
        self.schema = Nokogiri::XML::RelaxNG(f.read)
      end
    end
  end
end
