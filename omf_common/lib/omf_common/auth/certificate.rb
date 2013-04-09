require 'openssl'
require 'omf_common/auth'

module OmfCommon::Auth

  class Certificate
    DEF_DOMAIN_NAME = 'acme'
    DEF_DURATION = 3600

    BEGIN_CERT = "-----BEGIN CERTIFICATE-----\n"
    END_CERT = "\n-----END CERTIFICATE-----\n"
    @@serial = 0

    #
    def self.create(address, name, type, domain = DEF_DOMAIN_NAME, issuer = nil, not_before = Time.now, duration = 3600)
      subject = _create_name(name, type, domain)
      key, digest = _create_key()
      c = _create_x509_cert(address, subject, key, digest, issuer, not_before, duration)
      c[:address] = address if address
      self.new c
    end

    def self.create_from_x509(pem)
      unless pem.start_with? BEGIN_CERT
        pem = "#{BEGIN_CERT}#{pem}#{END_CERT}"
      end
      #puts pem
      cert = OpenSSL::X509::Certificate.new(pem)
      #puts cert
      self.new cert: cert
    end

    # Returns an array with a new RSA key and a SHA1 digest
    #
    def self._create_key(size = 2048)
      [OpenSSL::PKey::RSA.new(size), OpenSSL::Digest::SHA1.new]
    end

    def self._create_name(name, type, domain = nil)
      OpenSSL::X509::Name.new [['CN', "frcp//#{domain || @def_domain}//frcp.#{type}.#{name}"]], {}
    end


    # @return {cert, key}
    #
    def self._create_x509_cert(address, subject, key = nil, digest = nil,
                              issuer = nil, not_before = Time.now, duration = DEF_DURATION, extensions = [])
      #extensions ||= []
      extensions << ["subjectAltName", "URI:#{address}", false] if address
      unless key
        key, digest = create_key()
      end

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
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
      {cert: cert, key: key}
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
      #@domain = opts[:domain] || DEF_DOMAIN_NAME
      @cert ||= _create_x509_cert(@address, @subject, @key, @digest)[:cert]
    end

    def create_for(address, name, type, duration = 3600)
      raise "Address required" unless address
      cert = self.class.create(address, name, type, @domain, self, Time.now, duration)
      CertificateStore.instance.register(cert, address)
      cert
    end

    # Return the X509 certificate. If it hasn't been passed in, return a self-signed one
    def to_x509()
      @cert
    end

    def can_sign?
      @key != nil
    end

    def to_pem
      to_x509.to_pem
    end

    def to_pem_compact
      to_pem.lines.to_a[1 ... -1].join.strip
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
