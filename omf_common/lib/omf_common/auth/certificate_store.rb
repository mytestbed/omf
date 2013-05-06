require 'openssl'

require 'omf_common/auth'

module OmfCommon::Auth

  class MissingPrivateKeyException < AuthException; end

  class CertificateStore


    @@instance = nil

    def self.init(opts = {})
      if @@instance
        raise "CertificateStore already iniitalised"
      end
      @@instance = self.new(opts)
    end

    def self.instance
      throw "CertificateStore not initialized" unless @@instance
      @@instance
    end

    def register(certificate, address = nil)
      if address ||= certificate.address
        @certs[address] = certificate if address
      else
        warn "Register certificate without address - #{certificate}"
      end
      @certs[certificate.subject] = certificate
      begin
        @x509_store.add_cert(certificate.to_x509)
      rescue OpenSSL::X509::StoreError => e
        if e.message == "cert already in hash table"
          warn "X509 cert already register in X509 store"
        else
          raise e
        end
      end
    end

    def register_x509(cert_pem, address = nil)
      if (cert = Certificate.create_from_x509(cert_pem))
        debug "REGISTERED #{cert}"
        register(cert, address)
      end
    end

    def cert_for(url)
      @certs[url]
    end

    # @param [OpenSSL::X509::Certificate] cert
    #
    def verify(cert)
      cert = cert.to_x509 if cert.kind_of? OmfCommon::Auth::Certificate
      v_result = @x509_store.verify(cert)
      warn "Cert verification failed: '#{@x509_store.error_string}'" unless v_result
      v_result
    end

    private

    def initialize(opts)
      @x509_store = OpenSSL::X509::Store.new
      @x509_store.set_default_paths

      @certs = {}
      if store = opts[:store]
      else
        @store = {private: {}, public: {}}
      end
      @serial = 0
    end
  end # class

end # module
