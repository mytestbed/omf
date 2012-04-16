module OmfCommon
  # Refer to resource life cycle, instance methods are basically construct & parse XML fragment
  class Message < Niceogiri::XML::Node
    def create(name)
    end

    def conifgure(name)
    end

    def request(name)
    end

    def release
    end
  end
end
