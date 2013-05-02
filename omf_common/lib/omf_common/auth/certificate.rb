require 'openssl'
require 'omf_common/auth'
require 'omf_common/auth/ssh_pub_key_convert'

module OmfCommon::Auth

  class Certificate
    DEF_DOMAIN_NAME = 'acme'
    DEF_DURATION = 3600

    BEGIN_CERT = "-----BEGIN CERTIFICATE-----\n"
    END_CERT = "\n-----END CERTIFICATE-----\n"
    @@serial = 0

    # @param [String] name unique name of the entity (resource name)
    # @param [String] type type of the entity (resource type)
    # @param [String] domain of the resource
    #
    def self.create(address, name, type, domain = DEF_DOMAIN_NAME, issuer = nil, not_before = Time.now, duration = 3600, key = nil)
      subject = _create_name(name, type, domain)
      if key.nil?
        key, digest = _create_key()
      else
        digest = _create_digest
      end

      c = _create_x509_cert(address, subject, key, digest, issuer, not_before, duration)
      c[:address] = address if address
      self.new c
    end

    # @param [String] pem is the content of existing x509 cert
    # @param [OpenSSL::PKey::RSA|String] key is the private key which can be attached to the instance for signing.
    def self.create_from_x509(pem, key = nil)
      unless pem.start_with? BEGIN_CERT
        pem = "#{BEGIN_CERT}#{pem}#{END_CERT}"
      end
      cert = OpenSSL::X509::Certificate.new(pem)

      key = OpenSSL::PKey::RSA.new(key) if key && key.is_a?(String)

      if key && !cert.check_private_key(key)
        raise ArgumentError, "Private key provided could not match the public key of given certificate"
      end
      self.new({ cert: cert, key: key })
    end

    # Returns an array with a new RSA key and a SHA1 digest
    #
    def self._create_key(size = 2048)
      [OpenSSL::PKey::RSA.new(size), OpenSSL::Digest::SHA1.new]
    end

    def self._create_digest
      OpenSSL::Digest::SHA1.new
    end

    # @param [String] name unique name of the entity (resource name)
    # @param [String] type type of the entity (resource type)
    #
    def self._create_name(name, type, domain = DEF_DOMAIN_NAME)
      OpenSSL::X509::Name.new [['CN', "frcp//#{domain}//frcp.#{type}.#{name}"]], {}
    end

    # Create a X509 certificate
    #
    # @param [String] address
    # @param [String] subject
    # @param [OpenSSL::PKey::RSA] key
    # @return {cert, key}
    #
    def self._create_x509_cert(address, subject, key, digest = nil,
                              issuer = nil, not_before = Time.now, duration = DEF_DURATION, extensions = [])
      extensions << ["subjectAltName", "URI:#{address}", false] if address

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      # TODO change serial to non-sequential secure random numbers for production use
      cert.serial = (@@serial += 1)
      cert.subject = subject
      cert.public_key = key.public_key
      cert.not_before = not_before
      cert.not_after = not_before + duration
      unless extensions.empty?
        issuer_cert = issuer ? issuer.to_x509 : cert
        ef = OpenSSL::X509::ExtensionFactory.new
        ef.subject_certificate = cert
        ef.issuer_certificate = issuer_cert
        extensions.each{|oid, value, critical|
          cert.add_extension(ef.create_extension(oid, value, critical))
        }
      end
      if issuer
        cert.issuer = issuer.subject
        cert.sign(issuer.key, issuer.digest)
      else
        # self signed
        cert.issuer = subject
        cert.sign(key, digest)
      end
      { cert: cert, key: key }
    end

    attr_reader :address, :subject, :key, :digest

    def initialize(opts)
      if @cert = opts[:cert]
        @subject = @cert.subject
      end
      unless @address = opts[:address]
        # try to see it it is in cert
        if @cert
          @cert.extensions.each do |ext|
            if ext.oid == 'subjectAltName'
              @address = ext.value[4 .. -1] # strip off 'URI:'
            end
          end
        end
      end
      if @key = opts[:key]
        @digest = opts[:digest] || OpenSSL::Digest::SHA1.new
      end
      unless @subject ||= opts[:subject]
        name = opts[:name]
        type = opts[:type]
        domain = opts[:domain]
        @subject = _create_name(name, type, domain)
      end
      @cert ||= _create_x509_cert(@address, @subject, @key, @digest)[:cert]
    end

    # @param [OpenSSL::PKey::RSA|String] key is most likely the public key of the resource.
    #
    def create_for(address, name, type, domain = DEF_DOMAIN_NAME, duration = 3600, key = nil)
      raise ArgumentError, "Address required" unless address

      begin
        key = OpenSSL::PKey::RSA.new(key) if key && key.is_a?(String)
      rescue OpenSSL::PKey::RSAError
        # It might be a SSH pub key, try that
        key = OmfCommon::Auth::SSHPubKeyConvert.convert(key)
      end

      cert = self.class.create(address, name, type, domain, self, Time.now, duration, key)
      CertificateStore.instance.register(cert, address)
      cert
    end

    # Return the X509 certificate. If it hasn't been passed in, return a self-signed one
    def to_x509()
      @cert
    end

    def can_sign?
      !@key.nil? && @key.private?
    end

    def to_pem
      to_x509.to_pem
    end

    def to_pem_compact
      to_pem.lines.to_a[1 ... -1].join.strip
    end

    def verify_cert
      if @cert.issuer == self.subject # self signed cert
        @cert.verify(@cert.public_key)
      else
        @cert.verify(CertificateStore.instance.cert_for(@cert.issuer).to_x509.public_key)
      end
    end

    # Will return one of the following
    #
    # :HS256, :HS384, :HS512, :RS256, :RS384, :RS512, :ES256, :ES384, :ES512
    #
    # def key_algorithm
#
    # end

    def to_s
      "#<#{self.class} addr=#{@address} subj=#{@subject} can-sign=#{@key != nil}>"
    end
  end # class
end # module
