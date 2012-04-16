require 'niceogiri'
require 'securerandom'

module OmfCommon
  # Refer to resource life cycle, instance methods are basically construct & parse XML fragment
  class Message < Niceogiri::XML::Node
    def initialize
      @id ||= SecureRandom.uuid
    end

    def create(name)
    end

    def conifgure(name)
    end

    def request(name)
    end

    def release
    end

    def inform
    end

    def property
    end

    def valid?
    end
  end
end
