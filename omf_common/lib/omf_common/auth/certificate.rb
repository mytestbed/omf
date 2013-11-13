# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'openssl'
require 'omf_common/auth'
require 'omf_common/auth/ssh_pub_key_convert'
require 'uuidtools'

module OmfCommon::Auth

  class CertificateNoLongerValidException < AuthException; end

  class Certificate
    DEF_DOMAIN_NAME = 'acme'
    DEF_DURATION = 3600

    BEGIN_CERT = "-----BEGIN CERTIFICATE-----\n"
    END_CERT = "\n-----END CERTIFICATE-----\n"
    BEGIN_KEY = "-----BEGIN RSA PRIVATE KEY-----\n"
    END_KEY = "\n-----END RSA PRIVATE KEY-----\n"

    @@def_x509_name_prefix = [['C', 'US'], ['ST', 'CA'], ['O', 'ACME'], ['OU', 'Roadrunner']]
    @@def_email_domain = 'acme.org'
    #
    def self.default_domain(country, state, organisation, org_unit)
      @@def_x509_name_prefix = [
        ['C', c = country.upcase],
        ['ST', st = state.upcase],
        ['O', o = organisation],
        ['OU', ou = org_unit]
      ]
      "/C=#{c}/ST=#{st}/O=#{o}/OU=#{ou}"
    end

    def self.default_email_domain(email_domain)
      @@def_email_domain = email_domain
    end

    # @param [String] resource_id unique id of the resource entity
    # @param [String] resource_type type of the resource entity
    # @param [Certificate] Issuer
    # @param [Hash] options
    # @option [Time] :not_before Time the cert will be valid from [now]
    # @option [int] :duration Time in seconds this cert is valid for [3600]
    # @option [OpenSSL::PKey::RSA] :key Key to encode in cert. If not given, will create a new one
    # @option [String] :user_id ID (should be UUID) for user [UUID(email)]
    # @option [String] :email Email to identify user. If not give, user 'name' and @@def_email_domain
    # @option [String] :geni_uri
    # @option [String] :frcp_uri
    # @option [String] :frcp_domain
    # @option [String] :http_uri
    # @option [String] :http_prefix
    #
    def self.create_for_resource(resource_id, resource_type, issuer, opts = {})
      xname = @@def_x509_name_prefix.dup
      xname << ['CN', opts[:cn] || resource_id]
      subject = OpenSSL::X509::Name.new(xname)

      if key = opts[:key]
        digest = _create_digest
      else
        key, digest = _create_key()
      end

      addresses = opts[:addresses] || []
      addresses << "URI:uuid:#{opts[:resource_uuid]}" if opts[:resource_uuid]
      email_domain = opts[:email] ? opts[:email].split('@')[1] : @@def_email_domain
      addresses << (opts[:geni_uri] || "URI:urn:publicid:IDN+#{email_domain}+#{resource_type}+#{resource_id}")
      if frcp_uri = opts[:frcp_uri]
        unless frcp_uri.to_s.start_with? 'URI'
          frcp_uri = "URI:frcp:#{frcp_uri}"
        end
        addresses << frcp_uri
      end
          # opts[:frcp_uri] || "URI:frcp:#{user_id}@#{opts[:frcp_domain] || @@def_email_domain}",
          # opts[:http_uri] || "URI:http://#{opts[:http_prefix] || @@def_email_domain}/users/#{user_id}"
      not_before = opts[:not_before] || Time.now
      duration = opts[:duration] = 3600
      c = _create_x509_cert(subject, key, digest, issuer, not_before, duration, addresses)
      c[:addresses] = addresses
      c[:resource_id] = resource_id
      c[:subject] = subject
      self.new c
    end

    def self.create_root(opts = {})
      email = opts[:email] ||= "sa@#{@@def_email_domain}"
      opts = {
        addresses: [
          "email:#{email}"
        ]
      }.merge(opts)
      cert = create_for_resource('sa', :authority, nil, opts)
      CertificateStore.instance.register_trusted(cert)
      cert
    end

    # Return  a newly create certificate with properties tqken from
    # 'pem' encoded string.
    #
    # @param [String] pem is the PEM encoded content of existing x509 cert
    # @return [Certificate] Certificate object
    #
    def self.create_from_pem(pem_s, key = nil)
      state = :seeking
      cert_pem = []
      key_pem = []
      end_regexp = /^-*END/
      pem_s.each_line do |line|
        state = :seeking if line.match(end_regexp)
        case state
        when :seeking
          case line
          when /^-*BEGIN CERTIFICATE/
            state = :cert
          when /^-*BEGIN RSA PRIVATE KEY/
            state = :key
          end
        when :cert
          cert_pem << line
        when :key
          key_pem << line
        else
          raise "BUG: Unknown state '#{state}'"
        end
      end
      # Some command list generated cert can use \r\n as newline char
      cert_pem = cert_pem.join()
      unless cert_pem =~ /^-----BEGIN CERTIFICATE-----/
        cert_pem = "#{BEGIN_CERT}#{cert_pem.chomp}#{END_CERT}"
      end
      opts = {}
      opts[:cert] = OpenSSL::X509::Certificate.new(cert_pem)
      if key_pem.size > 0
        key_pem = key_pem.join()
        unless key_pem =~ /^-----BEGIN RSA PRIVATE KEY-----/
          key_pem = "#{BEGIN_KEY}#{key_pem.chomp}#{END_KEY}"
        end
        opts[:key] = OpenSSL::PKey::RSA.new(key_pem)
      end
      self.new(opts)
    end

    # Returns an array with a new RSA key and a SHA1 digest
    #
    def self._create_key(size = 2048)
      [OpenSSL::PKey::RSA.new(size), OpenSSL::Digest::SHA1.new]
    end

    def self._create_digest
      OpenSSL::Digest::SHA1.new
    end

    # Create a X509 certificate
    #
    # @param [String] address
    # @param [String] subject
    # @param [OpenSSL::PKey::RSA] key
    # @return {cert, key}
    #
    def self._create_x509_cert(subject, key, digest = nil,
                              issuer = nil, not_before = Time.now, duration = DEF_DURATION, addresses = [])

      if key.nil?
        key, digest = _create_key()
      else
        digest = _create_digest
      end

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      # TODO change serial to non-sequential secure random numbers for production use
      cert.serial = UUIDTools::UUID.random_create.to_i
      cert.subject = subject
      cert.public_key = key.public_key
      cert.not_before = not_before
      cert.not_after = not_before + duration
      #extensions << ["subjectAltName", "URI:http://foo.com/users/dc766130, URI:frcp:dc766130-c822-11e0-901e-000c29f89f7b@foo.com", false]

      issuer_cert = issuer ? issuer.to_x509 : cert
      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = issuer_cert
      unless addresses.empty?
        cert.add_extension(ef.create_extension("subjectAltName", addresses.join(','), false))
      end

      if issuer
        cert.issuer = issuer.subject
        cert.sign(issuer.key, issuer.digest)
      else
        # self signed
        cert.issuer = subject

        # Not exactly sure if that's the right extensions to add. Copied from
        # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/openssl/rdoc/OpenSSL/X509/Certificate.html
        cert.add_extension(ef.create_extension("basicConstraints", "CA:TRUE", true))
        cert.add_extension(ef.create_extension("keyUsage", "keyCertSign, cRLSign", true))
        cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash", false))
        cert.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always", false))

        # Signing the cert should be ABSOLUTELY the last step
        cert.sign(key, digest)
      end
      { cert: cert, key: key }
    end

    attr_reader :addresses, :resource_id # :addresses_raw, :addresses_string
    attr_reader :subject, :key, :digest

    def initialize(opts)
      if @cert = opts[:cert]
        @subject = @cert.subject
      end
      @resource_id = opts[:resource_id]
      _extract_addresses(@cert)
      unless @subject ||= opts[:subject]
        name = opts[:name]
        type = opts[:type]
        domain = opts[:domain]
        @subject = _create_name(name, type, domain)
      end
      if key = opts[:key]
        @digest = opts[:digest] || self.class._create_digest
      end
      if @cert
        self.key = key if key # this verifies that key is the right one for this cert
      else
        #@cert ||= _create_x509_cert(@address, @subject, @key, @digest)[:cert]
        @cert = self.class._create_x509_cert(@subject, key, @digest)[:cert]
        @key = key
      end
    end

    def valid?
      now = Time.new
      (@cert.not_before <= now && now <= @cert.not_after)
    end

    def key=(key)
      if @cert && !@cert.check_private_key(key)
        raise ArgumentError, "Private key provided could not match the public key of given certificate"
      end
      @key = key
    end

    def create_for_resource(resource_id, resource_type, opts = {})
      unless valid?
        raise CertificateNoLongerValidException.new
      end
      resource_id ||= UUIDTools::UUID.random_create()
      unless opts[:resource_uuid]
        if resource_id.is_a? UUIDTools::UUID
          opts[:resource_uuid] = resource_id
        else
          opts[:resource_uuid] = UUIDTools::UUID.random_create()
        end
      end
      unless opts[:cn]
        opts[:cn] = "#{resource_id}/type=#{resource_type}"
        (opts[:cn] += "/uuid=#{opts[:resource_uuid]}") unless resource_id.is_a? UUIDTools::UUID
      end
      cert = self.class.create_for_resource(resource_id, resource_type, self, opts)
      CertificateStore.instance.register(cert)
      cert
    end

    # See #create_for_resource for documentation on 'opts'
    def create_for_user(name, opts = {})
      unless valid?
        raise CertificateNoLongerValidException.new
      end
      email = opts[:email] || "#{name}@#{@@def_email_domain}"
      user_id = opts[:user_id] || UUIDTools::UUID.sha1_create(UUIDTools::UUID_URL_NAMESPACE, email)
      opts[:cn] = "#{user_id}/emailAddress=#{email}"
      opts[:addresses] = [
        "email:#{email}",
      ]
      create_for_resource(user_id, :user, opts)
    end

    # Return the X509 certificate. If it hasn't been passed in, return a self-signed one
    def to_x509()
      @cert
    end

    def can_sign?
      valid? && !@key.nil? && @key.private?
    end

    def root_ca?
      subject == @cert.issuer
    end

    def to_pem
      to_x509.to_pem
    end

    def to_pem_with_key
      to_x509.to_pem + @key.to_pem
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

    # Return a hash of some of the key properties of this cert.
    # To get the full monty, use 'openssl x509 -in xxx.pem -text'
    #
    def describe
      {
        subject: subject,
        issuer: @cert.issuer,
        addresses: addresses,
        can_sign: can_sign?,
        root_ca: root_ca?,
        valid: valid?,
        valid_period: [@cert.not_before, @cert.not_after]
      }
      #(@cert.methods - Object.new.methods).sort
    end

    # Will return one of the following
    #
    # :HS256, :HS384, :HS512, :RS256, :RS384, :RS512, :ES256, :ES384, :ES512
    #
    # def key_algorithm
    #
    # end

    def to_s
      "#<#{self.class} subj=#{@subject} can-sign=#{@key != nil}>"
    end

    def _extract_addresses(cert)
      addr = @addresses = {}
      return unless cert
      ext = cert.extensions.find { |ext| ext.oid == 'subjectAltName' }
      return unless ext
      @address_string = ext.value
      @addresses_raw = ext.value.split(',').compact
      @addresses_raw.each do |addr_s|
        parts = addr_s.split(':')
        #puts ">>>>>> #{parts}"
        case parts[0].strip
        when 'email'
          addr[:email] = parts[1]
        when 'URI'
          if parts[1] == 'urn'
            addr[:geni] = parts[3][4 .. -1]
          else
            addr[parts[1].to_sym] = parts[2]
          end
        else
          warn "Unknown address type '#{parts[0]}'"
        end
      end
    end
  end # class
end # module
