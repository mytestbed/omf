require 'niceogiri'
require 'hashie'
require 'securerandom'
require 'openssl'
require 'cgi'

require 'omf_common/message/xml/relaxng_schema'

module OmfCommon
class Message
class XML

  # @example To create a valid omf message, e.g. a 'create' message:
  #
  #   Message.create(:create,
  #                  { p1: 'p1_value', p2: { unit: 'u', precision: 2 } },
  #                  { guard: { p1: 'p1_value' } })
  class Message < OmfCommon::Message

    OMF_NAMESPACE = "http://schema.mytestbed.net/omf/#{OmfCommon::PROTOCOL_VERSION}/protocol"

    attr_accessor :xml

    class << self
      def create(operation_type, properties = {}, additional_content = {})
        new(additional_content.merge({
          operation: operation_type,
          type: operation_type,
          properties: properties
        }))
      end

      def parse(xml)
        raise ArgumentError, 'Can not parse an empty XML into OMF message' if xml.nil? || xml.empty?

        xml_node = Nokogiri::XML(xml).root

        self.create(xml_node.name.to_sym).tap do |message|
          message.xml = xml_node
          message.msg_id = message.read_element('msg_id')

          message.xml.elements.each do |el|
            unless %w(property digest).include? el.name
              message.send("#{el.name}=", message.read_element(el.name))
            end

            if el.name == 'property'
              message.read_element('property').each do |prop_node|
                message.send(:[]=,
                             prop_node.attr('key'),
                             message.reconstruct_data(prop_node))
              end
            end
          end

          if OmfCommon::Measure.enabled? && !@@msg_id_list.include?(message.msg_id)
            MPMessage.inject(Time.now.to_f, message.operation.to_s, message.msg_id, message.context_id, message.to_s.gsub("\n",''))
          end
        end
      end
    end

    %w(type operation guard msg_id timestamp inform_to context_id).each do |name|
      define_method(name) do |*args|
        @content[name]
      end

      define_method("#{name}=") do |value|
        @content[name] = value
      end
    end

    def to_s
      "XML Message: #{@content.inspect}"
    end

    def marshall
      build_xml
      @xml.to_xml
    end

    alias_method :to_xml, :marshall

    def build_xml
      @xml ||= Niceogiri::XML::Node.new(self.operation.to_s, nil, OMF_NAMESPACE)

      (INTERNAL_ATTR - %w(type operation)).each do |attr|
        attr_value = self.send(attr)

        next unless attr_value

        add_element(attr, attr_value) if attr != 'guard'
      end

      self.properties.each { |k, v| add_property(k, v) }

      digest = OpenSSL::Digest::SHA512.new(@xml.canonicalize)

      add_element(:digest, digest)
      @xml
    end

    # Construct a property xml node
    #
    def add_property(key, value = nil)
      key_node = Niceogiri::XML::Node.new('property')
      key_node.write_attr('key', key)

      unless value.nil?
        key_node.write_attr('type', ruby_type_2_prop_type(value.class))
        c_node = value_node_set(value)

        if c_node.class == Array
          c_node.each { |c_n| key_node.add_child(c_n) }
        else
          key_node.add_child(c_node)
        end
      end
      @xml.add_child(key_node)
      key_node
    end

    def value_node_set(value, key = nil)
      case value
      when Hash
        [].tap do |array|
          value.each_pair do |k, v|
            n = Niceogiri::XML::Node.new(k)
            n.write_attr('type', ruby_type_2_prop_type(v.class))

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
          n = Niceogiri::XML::Node.new('item')
          n.write_attr('type', ruby_type_2_prop_type(v.class))

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
          string_value(value)
        else
          n = Niceogiri::XML::Node.new(key)
          n.add_child(string_value(value))
        end
      end
    end

    # Generate SHA1 of canonicalised xml and write into the ID attribute of the message
    #
    def sign
      write_attr('msg_id', SecureRandom.uuid)
      write_attr('timestamp', Time.now.utc.iso8601)
      canonical_msg = self.canonicalize

      priv_key =  OmfCommon::Key.instance.private_key
      digest = OpenSSL::Digest::SHA512.new(canonical_msg)

      signature = Base64.encode64(priv_key.sign(digest, canonical_msg)).encode('utf-8') if priv_key
      write_attr('digest', digest)
      write_attr('signature', signature) if signature

      if OmfCommon::Measure.enabled?
        MPMessage.inject(Time.now.to_f, operation.to_s, msg_id, context_id, self.to_s.gsub("\n",''))
        @@msg_id_list << msg_id
      end
      self
    end

    # Validate against relaxng schema
    #
    def valid?
      build_xml

      validation = RelaxNGSchema.instance.schema.validate(@xml.document)
      if validation.empty?
        true
      else
        logger.error validation.map(&:message).join("\n")
        logger.debug @xml.to_s
        false
      end
    end

    # Short cut for adding xml node
    #
    def add_element(key, value = nil, &block)
      key_node = Niceogiri::XML::Node.new(key)
      @xml.add_child(key_node)
      if block
        block.call(key_node)
      else
        key_node.content = value if value
      end
      key_node
    end

    # Short cut for grabbing a group of nodes using xpath, but with default namespace
    def element_by_xpath_with_default_namespace(xpath_without_ns)
      @xml.xpath(xpath_without_ns.gsub(/(^|\/{1,2})(\w+)/, '\1xmlns:\2'), :xmlns => OMF_NAMESPACE)
    end

    # In case you think method :element_by_xpath_with_default_namespace is too long
    #
    alias_method :read_element, :element_by_xpath_with_default_namespace

    # We just want to know the content of an non-repeatable element
    #
    def read_content(element_name)
      element_content = read_element("#{element_name}").first.content rescue nil
      unless element_content.nil?
        element_content.empty? ? nil : element_content
      else
        nil
      end
    end

    # Reconstruct xml node into Ruby object
    #
    # @param [Niceogiri::XML::Node] property xml node
    # @return [Object] the content of the property, as string, integer, float, or mash(hash with indifferent access)
    def reconstruct_data(node, data_binding = nil)
      node_type =  node.attr('type')
      case node_type
      when 'array'
        node.element_children.map do |child|
          reconstruct_data(child, data_binding)
        end
      when /hash/
        mash ||= Hashie::Mash.new
        node.element_children.each do |child|
          mash[child.attr('key') || child.element_name] ||= reconstruct_data(child, data_binding)
        end
        mash
      when /boolean/
        node.content == "true"
      else
        if node.content.empty?
          nil
        elsif data_binding && node_type == 'string'
          ERB.new(node.content).result(data_binding)
        else
          node.content.ducktype
        end
      end
    end

    def <=>(another)
      @content <=> another.content
    end

    def properties
      @content.properties
    end

    def has_properties?
      @content.properties.empty?
    end

    def guard?
      @content.guard.empty?
    end

    # Pretty print for application event message
    #
    def print_app_event
      "APP_EVENT (#{read_property(:app)}, ##{read_property(:seq)}, #{read_property(:event)}): #{read_property(:msg)}"
    end

    # Iterate each property key value pair
    #
    def each_property(&block)
      properties.each { |k, v| block.call(k, v) }
    end

    def [](name, evaluate = false)
      value = properties[name]

      if evaluate && value.kind_of?(String)
        ERB.new(value).result(evaluate)
      else
        value
      end
    end

    alias_method :read_property, :[]

    alias_method :write_property, :[]=

    private

    def initialize(content = {})
      @content = Hashie::Mash.new(content)
      @content.msg_id = SecureRandom.uuid
      @content.timestamp = Time.now.utc.iso8601
    end

    def _set_core(key, value)
      @content[key] = value
    end

    def _get_core(key)
      @content[key]
    end

    def _set_property(key, value)
      @content.properties[key] = value
    end

    def _get_property(key)
      @content.properties[key]
    end

    def ruby_type_2_prop_type(ruby_class_type)
      v_type = ruby_class_type.to_s.downcase
      case v_type
      when *%w(trueclass falseclass)
        'boolean'
      when *%w(fixnum bignum)
        'integer'
      else
        v_type
      end
    end

    # Get string of a value object, escape if object is string
    def string_value(value)
      if value.kind_of? String
        value = CGI::escape_html(value)
      else
        value = value.to_s
      end
      value
    end
  end
end
end
end

