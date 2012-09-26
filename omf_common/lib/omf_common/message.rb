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
  #     message.property('memory', { value: 2, unit: 'gb' })
  #   end
  #
  class Message < Niceogiri::XML::Node
    OMF_NAMESPACE = "http://schema.mytestbed.net/#{OmfCommon::PROTOCOL_VERSION}/protocol"
    SCHEMA_FILE = "#{File.dirname(__FILE__)}/protocol/#{OmfCommon::PROTOCOL_VERSION}.rng"
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
    def property(key, value = nil)
      key_node = Message.new('property')
      key_node.write_attr('key', key)

      unless value.nil?
        key_node.write_attr('type', value.class.to_s.downcase)
        c_node = value_node_set(value)

        if c_node.class == Array
          c_node.each { |c_n| key_node.add_child(c_n) }
        else
          key_node.add_child(c_node)
        end
      end
      add_child(key_node)
      key_node
    end

    def value_node_set(value, key = nil)
      case value
      when Hash
        [].tap do |array|
          value.each_pair do |k, v|
            n = Message.new(k)
            n.write_attr('type', v.class.to_s.downcase)

            c_node = value_node_set(v, k)
            if c_node.class == Array
              c_node.each { |c_n| n.add_child(c_n) }
            else
              n.add_child(c_node)
            end
            array << n
          end
        end
      when Array
        value.map do |v|
          n = Message.new('item')
          n.write_attr('type', v.class.to_s.downcase)

          c_node = value_node_set(v, 'item')
          if c_node.class == Array
            c_node.each { |c_n| n.add_child(c_n) }
          else
            n.add_child(c_node)
          end
          n
        end
      else
        if key.nil?
          value.to_s
        else
          n = Message.new(key)
          n.add_child(value.to_s)
        end
      end
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
      validation = Nokogiri::XML::RelaxNG(File.open(SCHEMA_FILE)).validate(self.document)
      if validation.empty?
        true
      else
        logger.error validation.map(&:message).join("\n")
        logger.debug self.to_s
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
      reconstruct_data(e) if e
    end

    def reconstruct_data(node)
      case node.attr('type')
      when 'array'
        mash ||= Hashie::Mash.new
        mash[:items] = node.element_children.map do |child|
          reconstruct_data(child)
        end
        mash
      when /hash/
        mash ||= Hashie::Mash.new
        node.element_children.each do |child|
          mash[child.attr('key') || child.element_name] ||= reconstruct_data(child)
        end
        mash
      else
        node.content.ducktype
      end
    end

    # Iterate each property element
    #
    def each_property(&block)
      read_element("//property").each { |v| block.call(v) }
    end

    # Pretty print for application event message
    #
    def print_app_event
      "APP_EVENT (#{read_property(:app)}, ##{read_property(:seq)}, #{read_property(:event)}): #{read_property(:msg)}"
    end
  end
end
