require 'openssl'

require 'omf_common/auth'

#require 'singleton'

# module OmfCommon
  # class Key
    # include Singleton
#
    # attr_accessor :private_key
#
    # def import(filename)
      # self.private_key = OpenSSL::PKey.read(File.read(filename))
    # end
  # end
# end

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


    private
    def initialize(opts)
      @certs = {}
      if store = opts[:store]
      else
        @store = {private: {}, public: {}}
      end
      @serial = 0
    end
  end # class

end # module
