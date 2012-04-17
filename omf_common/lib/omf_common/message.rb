require 'niceogiri'
require 'securerandom'

module OmfCommon
  # Refer to resource life cycle, instance methods are basically construct & parse XML fragment
  class Message < Niceogiri::XML::Node
    OMF_NAMESPACE = "http://schema.mytestbed.net/#{OmfCommon::VERSION}/protocol"

    OPERATION = %w(create configure request release inform)

    class << self
      OPERATION.each do |operation|
        define_method(operation) do |*args, &block|
          xml = new(operation, nil, OMF_NAMESPACE)
          xml.write_attr('id', SecureRandom.uuid)
          block.call(xml) if block
          xml
        end
      end
    end

    def property(key, value)
      p_node = Niceogiri::XML::Node.new('property')
      p_node.write_attr('id', key)
      p_node.content = value
      self.add_child(p_node)
    end

    def valid?
      true
    end
  end
end
