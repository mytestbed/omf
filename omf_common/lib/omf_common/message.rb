require 'niceogiri'
require 'securerandom'
require 'openssl'

module OmfCommon
  # Refer to resource life cycle, instance methods are basically construct & parse XML fragment
  #
  # To create a valid omf message, e.g. a 'configure' message, simply do:
  #
  # Message.request do |message|
  #   message.property('os', 'debian')
  #   message.property('memory', 2) do |p|
  #     p.element('unit', 'gb')
  #   end
  # end.sign
  #
  class Message < Niceogiri::XML::Node
    OMF_NAMESPACE = "http://schema.mytestbed.net/#{OmfCommon::PROTOCOL_VERSION}/protocol"

    OPERATION = %w(create configure request release inform)

    class << self
      OPERATION.each do |operation|
        define_method(operation) do |*args, &block|
          xml = new(operation, nil, OMF_NAMESPACE)
          xml.add_child(
            MessageElement.new.element(
              'context_id',
              operation == 'inform' ? args.first : SecureRandom.uuid)
          )
          xml.add_child(MessageElement.new.element('publish_to', args.first)) if operation == 'request'
          block.call(xml) if block
          xml
        end
      end
    end

    def property(key, value = nil, &block)
      key_node = MessageElement.new(key)
      self.add_child(key_node)
      if block
        if value
          value_node = MessageElement.new('value')
          value_node.content = value
          key_node.add_child(value_node)
        end
        block.call(key_node)
      else
        key_node.content = value if value
      end
      key_node
    end

    # Generate SHA1 of canonical xml and write into the ID attribute of the message
    #
    def sign
      write_attr('id', OpenSSL::Digest::SHA1.new(canonicalize)) if read_attr('id').nil? || read_attr('id').empty?
      self
    end

    def valid?
      true
    end
  end

  class MessageElement < Niceogiri::XML::Node
    def element(key, value)
      key_node = MessageElement.new(key)
      key_node.content = value
      self.add_child(key_node)
    end
  end
end
