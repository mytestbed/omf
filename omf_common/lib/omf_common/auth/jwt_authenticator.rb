
require 'json'
require 'json/jwt'

module OmfCommon::Auth
  class JWTAuthenticator

    def self.sign(content, signer, signer_name = signer.subject)
      msg = {cnt: content, iss: signer_name.to_s}
      JSON::JWT.new(msg).sign(signer.key , :RS256).to_s
    end

    def self.parse(jwt_string)
      jwt_string = jwt_string.split.join
      # Code lifted from 'json-jwt-0.4.3/lib/json/jwt.rb'
      case jwt_string.count('.')
      when 2 # JWT / JWS
        header, claims, signature = jwt_string.split('.', 3).collect do |segment|
          UrlSafeBase64.decode64 segment.to_s
        end
        header, claims = [header, claims].collect do |json|
          #MultiJson.load(json).with_indifferent_access
          puts "JSON>>> #{json}"
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
        # if cert_pem = claims[:crt]
          # # let's the credential store take care of it
          # OmfCommon::Auth::CertificateStore.instance.register_x509(cert_pem, src)
        # end
        cert = nil
        issuer.split(',').compact.select do |addr|
          begin
            cert = OmfCommon::Auth::CertificateStore.instance.cert_for(addr)
          rescue OmfCommon::Auth::MissingCertificateException
            nil
          end
        end
        unless cert
          warn "JWT: Can't find cert for issuer '#{issuer}'"
          return nil
        end

        unless OmfCommon::Auth::CertificateStore.instance.verify(cert)
          warn "JWT: Invalid certificate '#{cert.to_s}', NOT signed by CA certs, or its CA cert NOT loaded into cert store."
        end

        jwt.verify signature_base_string, cert.to_x509.public_key
        #JSON.parse(claims[:cnt], :symbolize_names => true)
        claims[:cnt]
      else
        warn('JWT: Invalid Format. JWT should include 2 or 3 dots.')
        return nil
      end
    end

  end # class
end # module