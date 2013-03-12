
require 'json'
require 'omf_common/auth'

module OmfCommon
  class Message
    class Json
      class Message < OmfCommon::Message
        
        @@key2json_key = {
          operation: :op,
          res_id: :rid
        }
                

        def self.create(type, properties, body = {})
          if type == :request 
            unless properties.kind_of?(Array)
              raise "Expected array, but got #{properties.class} for request message"
            end
            properties = {select: properties}
          elsif not properties.kind_of?(Hash)
            raise "Expected hash, but got #{properties.class}"
          end 
          content = body.merge({
            op: type,
            mid: SecureRandom.uuid,
            props: properties
          })
          self.new(content)
        end
        
        def self.create_inform_message(itype = nil, properties = {}, body = {})
          body[:itype] = itype if itype
          create(:inform, properties, body)
        end
        
        # Create and return a message by parsing 'str'
        #
        def self.parse(str, content_type)
          #puts "CT>> #{content_type}"
          content = JSON.parse(str, :symbolize_names => true)
          #puts content
          new(content)
        end
                
        def each_property(&block)
          @properties.each do |k, v|
            #unless INTERNAL_PROPS.include?(k.to_sym)
              block.call(k, v)
            #end
          end
        end
        
        def has_properties?
          not @properties.empty?
        end
        
        def valid?
          true # don't do schema verification , yet
        end
        
        # Loop over all the unbound (sent without a value) properties 
        # of a request message.
        #
        def each_unbound_request_property(&block)
          unless type == :request
            raise "Can only be used for request messages"
          end
          self[:select].each do |el|
            #puts "UUU: #{el}::#{el.class}"
            if el.is_a? Symbol
              block.call(el)
            end
          end
        end    
    
        # Loop over all the bound (sent with a value) properties 
        # of a request message.
        #
        def each_bound_request_property(&block)
          unless type == :request
            raise "Can only be used for request messages"
          end
          self[:select].each do |el|
            #puts "BBB #{el}::#{el.class}"
            if el.is_a? Hash
              el.each do |key, value|
                block.call(key, value)
              end
            end
          end
        end    
        
                
        def to_s
          "JsonMessage: #{@content.inspect}"
        end
        
        def marshall
          puts "MARSHALL: #{@content.inspect} - #{@properties.to_hash.inspect}"
          raise "Missing SRC declaration in #{@content}" unless @content[:src]
          raise 'local/local' if @content[:src].match 'local:/local'
          if self.class.authenticate?
             src = @content[:src]
             if cert = OmfCommon::Auth::CertificateStore.instance.cert_for(src)
               puts ">>> Found cert for '#{src} - #{cert}"
             end
          end
          ['text/json', @content.to_json]
        end
        
        private 
        def initialize(content)
          debug "Create message: #{content.inspect}"
          unless op = content[:op]
            raise "Missing message type (:operation)"
          end
          @content = {}
          content[:op] = op.to_sym # needs to be symbol
          content.each {|k,v| _set_core(k, v)}
          @properties = content[:props] || []
          #@properties = Hashie::Mash.new(content[:properties])
          @authenticate = self.class.authenticate?
        end
        
        def _set_core(key, value)
          @content[(@@key2json_key[key] || key).to_sym] = value
        end

        def _get_core(key)
          @content[@@key2json_key[key] || key]
        end
        
        def _set_property(key, value)
          @properties[key] = value
        end

        def _get_property(key)
          #puts key
          @properties[key]
        end
        
      end # class
    end
  end
end 