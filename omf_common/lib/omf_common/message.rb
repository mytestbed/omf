require 'niceogiri'
require 'hashie'
require 'securerandom'
require 'openssl'
require 'cgi'
require 'omf_common/relaxng_schema'

module OmfCommon

  class MPMessage < OML4R::MPBase
    name :message
    param :time, :type => :double
    param :operation, :type => :string
    param :msg_id, :type => :string
    param :context_id, :type => :string
    param :content, :type => :string
  end

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
    OMF_NAMESPACE = "http://schema.mytestbed.net/omf/#{OmfCommon::PROTOCOL_VERSION}/protocol"
    OPERATION = %w(create configure request release inform)
    # When OML instrumentation is enabled, we do not want to send a the same
    # measurement twice, once when a message is created for publishing to T,
    # and once when this message comes back (as we are also a subscriber of T)
    # Thus we keep track of message IDs here (again only when OML is enabled)
    @@msg_id_list = []

    class << self
      OPERATION.each do |operation|
        define_method(operation) do |*args, &block|
          xml = new(operation, nil, OMF_NAMESPACE)
          if operation == 'inform'
            xml.element('context_id', args[1]) if args[1]
            xml.element('inform_type', args[0])
          else
            xml.element('publish_to', args[0]) if args[0]
          end
          block.call(xml) if block
          xml.sign
        end
      end

      def parse(xml)
        raise ArgumentError, 'Can not parse an empty XML into OMF message' if xml.nil? || xml.empty?
        xml_root = Nokogiri::XML(xml).root
        result = new(xml_root.element_name, nil, xml_root.namespace.href).inherit(xml_root)
        if OmfCommon::Measure.enabled? && !@@msg_id_list.include?(result.msg_id)
          MPMessage.inject(Time.now.to_f, result.operation.to_s, result.msg_id, result.context_id, result.to_s.gsub("\n",''))
        end
        result
      end
    end

    # Construct a property xml node
    #
    def property(key, value = nil)
      key_node = Message.new('property')
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
      add_child(key_node)
      key_node
    end

    def value_node_set(value, key = nil)
      case value
      when Hash
        [].tap do |array|
          value.each_pair do |k, v|
            n = Message.new(k)
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
          n = Message.new('item')
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
          n = Message.new(key)
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

    # param :time, :type => :int32
    # param :operation, :type => :string
    # param :msg_id, :type => :string
    # param :context_id, :type => :string
    # param :content, :type => :string


    # Validate against relaxng schema
    #
    def valid?
      validation = RelaxNGSchema.instance.schema.validate(self.document)
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
      element_content = read_element("//#{element_name}").first.content rescue nil
      unless element_content.nil?
        element_content.empty? ? nil : element_content
      else
        nil
      end
    end

    # Context ID will be requested quite often
    def context_id
      read_property(:context_id) || read_content(:context_id)
    end

    # Resource ID is another frequent requested property
    def resource_id
      read_property(:resource_id) || read_content(:resource_id)
    end

    def publish_to
      read_property(:publish_to) || read_content(:publish_to)
    end

    def msg_id
      read_attr('msg_id')
    end

    # Get a property by key
    #
    # @param [String] key name of the property element
    # @return [Object] the content of the property, as string, integer, float, or mash(hash with indifferent access)
    #
    def read_property(key, data_binding = nil)
      key = key.to_s
      e = read_element("//property[@key='#{key}']").first
      reconstruct_data(e, data_binding) if e
    end

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

    private

    def ruby_type_2_prop_type(ruby_class_type)
      v_type = ruby_class_type.to_s.downcase
      if %w(trueclass falseclass).include?(v_type)
        'boolean'
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
