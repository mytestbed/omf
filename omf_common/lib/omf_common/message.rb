require 'niceogiri'
require 'hashie'
require 'securerandom'
require 'openssl'

module OmfCommon
  # Refer to resource life cycle, instance methods are basically construct & parse XML fragment
  #
  # @example To create a valid omf message, e.g. a 'configure' message:
  #
  #   Message.request do |message|
  #     message.property('os', 'debian')
  #     message.property('memory', 2) do |p|
  #       p.element('unit', 'gb')
  #     end
  #   end
  #
  class Message < Niceogiri::XML::Node
    OMF_NAMESPACE = "http://schema.mytestbed.net/#{OmfCommon::PROTOCOL_VERSION}/protocol"
    SCHEMA_FILE = "#{File.dirname(__FILE__)}/protocol.rng"
    OPERATION = %w(create configure request release inform)

    class << self
      OPERATION.each do |operation|
        define_method(operation) do |*args, &block|
          xml = new(operation, nil, OMF_NAMESPACE)
          if operation == 'inform'
            xml.element('context_id', args[1] || SecureRandom.uuid)
            xml.element('inform_type', args[0])
          else
            xml.element('context_id', SecureRandom.uuid)
          end
          xml.element('publish_to', args[0]) if operation == 'request'
          block.call(xml) if block
          xml.sign
        end
      end

      def parse(xml)
        xml_root = Nokogiri::XML(xml).root
        new(xml_root.element_name, nil, xml_root.namespace.href).inherit(xml_root)
      end
    end

    # Construct a property xml node
    #
    def property(key, value = nil, &block)
      key_node = Message.new('property')
      key_node.write_attr('key', key)
      add_child(key_node)
      if block
        key_node.element('value', value) if value
        block.call(key_node)
      else
        key_node.content = value if value
      end
      key_node
    end

    # Generate SHA1 of canonicalised xml and write into the ID attribute of the message
    #
    def sign
      write_attr('msg_id', OpenSSL::Digest::SHA1.new(canonicalize)) if read_attr('id').nil? || read_attr('id').empty?
      self
    end

    # Validate against relaxng schema
    #
    def valid?
      validation = Nokogiri::XML::RelaxNG(File.open(SCHEMA_FILE)).validate(document)
      if validation.empty?
        true
      else
        logger.error validation.map(&:message).join("\n")
        logger.debug to_s
        false
      end
    end

    # Short cut for adding xml node
    #
    def element(key, value = nil, &block)
      key_node = Message.new(key)
      add_child(key_node)
      if block
        block.call(key_node)
      else
        key_node.content = value if value
      end
    end

    # The root element_name represents operation
    #
    def operation
      element_name.to_sym
    end

    # Short cut for grabbing a group of nodes using xpath, but with default namespace
    def element_by_xpath_with_default_namespace(xpath_without_ns)
      xpath(xpath_without_ns.gsub(/(\/+)(\w+)/, '\1xmlns:\2'), :xmlns => OMF_NAMESPACE)
    end

    # In case you think method :element_by_xpath_with_default_namespace is too long
    #
    alias_method :read_element, :element_by_xpath_with_default_namespace

    # We just want to know the content of an non-repeatable element
    #
    def read_content(element_name)
      read_element("//#{element_name}").first.content rescue nil
    end

    # Context ID will be requested quite often
    def context_id
      read_property(:context_id) || read_content(:context_id)
    end

    # Resource ID is another frequent requested property
    def resource_id
      read_property(:resource_id) || read_content(:resource_id)
    end

    # Get a property by key
    #
    # @param [String] key name of the property element
    # @return [Object] the content of the property, as string, integer, float, or mash(hash with indifferent access)
    #
    def read_property(key)
      key = key.to_s
      e = read_element("//property[@key='#{key}']").first
      if e
        if e.children.size == 1
          e.content.ducktype
        else
          Hashie::Mash.new.tap do |mash|
            e.element_children.each do |child|
              puts "*"
              puts child
              mash[child.element_name] ||= child.content.ducktype
            end
          end
        end
      end
    end

    # Iterate each property element
    def each_property(&block)
      read_element("//property").each { |v| block.call(v) }
    end
  end
end
