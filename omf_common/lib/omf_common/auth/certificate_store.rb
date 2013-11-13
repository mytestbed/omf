# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'openssl'
require 'monitor'

require 'omf_common/auth'

module OmfCommon::Auth

  class MissingPrivateKeyException < AuthException; end
  class MissingCertificateException < AuthException; end

  class CertificateStore
    include MonitorMixin

    @@instance = nil

    def self.init(opts = {})
      if @@instance
        raise "CertificateStore already initialized"
      end
      @@instance = self.new(opts)
    end

    def self.instance
      throw "CertificateStore not initialized" unless @@instance
      @@instance
    end

    def register_trusted(certificate)
      @@instance.synchronize do
        begin
          @x509_store.add_cert(certificate.to_x509)
        rescue OpenSSL::X509::StoreError => e
          if e.message == "cert already in hash table"
            raise "X509 cert '#{address}' already registered in X509 store"
          else
            raise e
          end
        end
        @certs[certificate.subject] ||= certificate
      end
    end

    def register(certificate)
      raise "Expected Certificate, but got '#{certificate.class}'" unless certificate.is_a? Certificate

      debug "Registering certificate for '#{certificate.addresses}' - #{certificate.subject}"
      @@instance.synchronize do
        _set(certificate.subject, certificate)
        if rid = certificate.resource_id
          _set(rid, certificate)
        end
        certificate.addresses.each do |type, name|
          _set(name, certificate)
        end
      end
    end

    def register_x509(cert_pem)
      if (cert = Certificate.create_from_pem(cert_pem))
        debug "REGISTERED #{cert}"
        register(cert)
      end
    end

    def cert_for(url)
      # The key of @certs could be a OpenSSL::X509::Name instance
      unless (cert = @certs.find { |k, v| k.to_s == url.to_s })
        warn "Unknown cert '#{url}'"
        raise MissingCertificateException.new(url)
      end
      cert[1]
    end

    # @param [OpenSSL::X509::Certificate] cert
    #
    def verify(cert)
      #puts "VERIFY: #{cert}::#{cert.class}}"
      cert = cert.to_x509 if cert.kind_of? OmfCommon::Auth::Certificate
      v_result = @x509_store.verify(cert)
      warn "Cert verification failed: '#{@x509_store.error_string}'" unless v_result
      v_result
    end

    # Load a set of CA certs into cert store from a given location
    #
    # @param [String] folder contains all the CA certs
    #
    def register_default_certs(folder)
      Dir["#{folder}/*"].each do |cert|
        register_x509(File.read(cert))
      end
    end

    private

    def initialize(opts)
      @x509_store = OpenSSL::X509::Store.new

      @certs = {}
      if store = opts[:store]
      else
        @store = {private: {}, public: {}}
      end
      @serial = 0

      super()
    end

    def _set(name, certificate)
      if old = @certs[name]
        return if old.to_pem == certificate.to_pem
        warn "Overriding certificate '#{name}' - new: #{certificate.subject} old: #{old.subject}"
      end
      @certs[name] = certificate
      unless name.is_a? String
        _set(name.to_s, certificate)
      end
    end
  end # class

end # module
