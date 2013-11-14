# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.


require 'json'
require 'omf_common/auth'
require 'json/jwt'

module OmfCommon
  class Message
    class Json
      class Message < OmfCommon::Message

        # This maps properties in the internal representation of
        # a message to names used for the JSON message
        #
        @@key2json_key = {
          operation: :op,
          res_id: :rid
        }

        def self.create(type, properties, body = {})
          if type == :request
            unless (req_props = properties).kind_of?(Array)
              raise "Expected array, but got #{properties.class} for request message"
            end
            #properties = {select: properties}
            properties = {}
            req_props.each {|n| properties[n] = nil }

          elsif not properties.kind_of?(Hash)
            raise "Expected hash, but got #{properties.class}"
          end
          content = body.merge({
            op: type,
            mid: SecureRandom.uuid,
            props: properties
          })
          issuer = self.authenticate? ? (body[:issuer] || body[:src]) : nil
          self.new(content, issuer)
        end

        def self.create_inform_message(itype = nil, properties = {}, body = {})
          body[:itype] = itype if itype
          create(:inform, properties, body)
        end

        # Create and authenticate, if necessary a message and pass it
        # on to 'block' if parsing (and authentication) is successful.
        #
        def self.parse(str, content_type, &block)
          #puts "CT>> #{content_type}"
          issuer = nil
          case content_type.to_s
          when 'jwt'
            content, issuer = parse_jwt(str, &block)
          when 'text/json'
            content = JSON.parse(str, :symbolize_names => true)
          else
            warn "Received message with unknown content type '#{content_type}'"
          end
          #puts "CTTT>> #{content}::#{content.class}"
          if (content)
            msg = new(content, issuer)
            block.call(msg)
          end
        end

        def self.parse_jwt(jwt_string)
          key_or_secret = :skip_verification
          # Code lifted from 'json-jwt-0.4.3/lib/json/jwt.rb'
          case jwt_string.count('.')
          when 2 # JWT / JWS
            header, claims, signature = jwt_string.split('.', 3).collect do |segment|
              UrlSafeBase64.decode64 segment.to_s
            end
            header, claims = [header, claims].collect do |json|
              #MultiJson.load(json).with_indifferent_access
              JSON.parse(json, :symbolize_names => true)
            end
            signature_base_string = jwt_string.split('.')[0, 2].join('.')
            jwt = JSON::JWT.new claims
            jwt.header = header
            jwt.signature = signature

            # NOTE:
            #  Some JSON libraries generates wrong format of JSON (spaces between keys and values etc.)
            #  So we need to use raw base64 strings for signature verification.
            unless issuer = claims[:iss]
              warn "JWT: Message is missing :iss element"
              return nil
            end
            if ceat_pem = claims[:crt]
              # let's the credential store take care of it
              pem = "#{OmfCommon::Auth::Certificate::BEGIN_CERT}#{cert_pem}#{OmfCommon::Auth::Certificate::END_CERT}"
              OmfCommon::Auth::CertificateStore.instance.register_x509(pem)
            end
            unless cert = OmfCommon::Auth::CertificateStore.instance.cert_for(issuer)
              warn "JWT: Can't find cert for issuer '#{issuer}'"
              return nil
            end

            unless OmfCommon::Auth::CertificateStore.instance.verify(cert)
              warn "JWT: Invalid certificate '#{cert.to_s}', NOT signed by CA certs, or its CA cert NOT loaded into cert store."
            end

            #puts ">>> #{cert.to_x509.public_key}::#{signature_base_string}"
            jwt.verify signature_base_string, cert.to_x509.public_key #unless key_or_secret == :skip_verification
            [JSON.parse(claims[:cnt], :symbolize_names => true), cert]
          else
            warn('JWT: Invalid Format. JWT should include 2 or 3 dots.')
            return nil
          end
        end

        def each_property(&block)
          @properties.each do |k, v|
            #unless INTERNAL_PROPS.include?(k.to_sym)
              block.call(k, v)
            #end
          end
        end

        def properties
          @properties
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

        # Marshall message into a string to be shipped across the network.
        # Depending on authentication setting, the message will be signed as
        # well, or maybe even dropped.
        #
        # @param [Topic] topic for which to marshall
        #
        def marshall(topic)
          #puts "MARSHALL: #{@content.inspect} - #{@properties.to_hash.inspect}"
          raise "Missing SRC declaration in #{@content}" unless @content[:src]
          if @content[:src].is_a? OmfCommon::Comm::Topic
            @content[:src] = @content[:src].address
          end
          @content[:itype] = self.itype(:frcp)

          #raise 'local/local' if @content[:src].id.match 'local:/local'
          #puts @content.inspect
          payload = @content.to_json
          if self.class.authenticate?
             unless issuer = self.issuer
               raise "Missing ISSUER for '#{self}'"
             end
             if issuer.is_a? OmfCommon::Auth::CertificateStore
               cert = issuer
               issuer = cert.subject
             else
               cert = OmfCommon::Auth::CertificateStore.instance.cert_for(issuer)
             end
             if cert && cert.can_sign?
               debug "Found cert for '#{issuer} - #{cert}"
               msg = {cnt: payload, iss: issuer}
               unless @certOnTopic[k = [topic, issuer]]
                 # first time for this issuer on this topic, so let's send the cert along
                 msg[:crt] = cert.to_pem_compact
                 #ALWAYS ADD CERT @certOnTopic[k] = Time.now
               end
               #:RS256, :RS384, :RS512
               p = JSON::JWT.new(msg).sign(cert.key , :RS256).to_s
               #puts "SIGNED>> #{msg}"
               return ['jwt', p]
             end
          end
          ['text/json', payload]
        end

        private
        def initialize(content, issuer = nil)
          debug "Create message: #{content.inspect}"
          unless op = content[:op]
            raise "Missing message type (:operation)"
          end
          @content = {}
          @issuer = issuer
          content[:op] = op.to_sym # needs to be symbol
          if src = content[:src]
            content[:src] = OmfCommon.comm.create_topic(src)
          end
          content.each {|k,v| _set_core(k, v)}
          @properties = content[:props] || []
          #@properties = Hashie::Mash.new(content[:properties])
          @authenticate = self.class.authenticate?
          # keep track if we sent local certs on a topic. Should do this the first time
          @certOnTopic = {}
        end

        def _set_core(key, value)
          @content[(@@key2json_key[key] || key).to_sym] = value
        end

        def _get_core(key)
          @content[@@key2json_key[key] || key]
        end

        def _set_property(key, value, ns = nil)
          warn "Can't handle namespaces yet" if ns
          @properties[key] = value
        end

        def _get_property(key, ns = nil)
          warn "Can't handle namespaces yet" if ns
          #puts key
          @properties[key]
        end

      end # class
    end
  end
end