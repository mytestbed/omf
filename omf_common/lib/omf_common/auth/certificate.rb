# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'openssl'
require 'omf_common/auth'
require 'omf_common/auth/ssh_pub_key_convert'
require 'uuidtools'

module OmfCommon::Auth

  class Certificate
    DEF_DOMAIN_NAME = 'acme'
    DEF_DURATION = 3600

    BEGIN_CERT = "-----BEGIN CERTIFICATE-----\n"
    END_CERT = "\n-----END CERTIFICATE-----\n"
    @@serial = 0

    @@def_x509_name_prefix = [['C', 'US'], ['ST', 'CA'], ['O', 'ACME'], ['OU', 'Roadrunner']]
    @@def_email_domain = 'acme.org'
    #
    def self.default_domain(country, state, organisation, org_unit)
      @@def_x509_name_prefix = [
        ['C', country.upcase],
        ['ST', state.upcase],
        ['O', organisation],
        ['OU', org_unit]
      ]
    end

    def self.default_email_domain(email_domain)
      @@def_email_domain = email_domain
    end

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

    # @param [String] name unique name of the entity (resource name)
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
      addresses << (opts[:geni_uri] || "URI:urn:publicid:IDN+#{@@def_email_domain}+#{resource_type}+#{resource_id}")
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


    # @param [String] pem is the content of existing x509 cert
    # @param [OpenSSL::PKey::RSA|String] key is the private key which can be attached to the instance for signing.
    def self.create_from_x509(pem, key = nil)
      # Some command list generated cert can use \r\n as newline char
      unless pem =~ /^-----BEGIN CERTIFICATE-----/
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
    # def self._create_name(name, type, domain = DEF_DOMAIN_NAME)
      # OpenSSL::X509::Name.new [['CN', "frcp//#{domain}//frcp.#{type}.#{name}"]], {}
    # end

    # Create a X509 certificate
    #
    # @param [String] address
    # @param [String] subject
    # @param [OpenSSL::PKey::RSA] key
    # @return {cert, key}
    #
    def self._create_x509_cert(subject, key, digest = nil,
                              issuer = nil, not_before = Time.now, duration = DEF_DURATION, addresses = [])

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      # TODO change serial to non-sequential secure random numbers for production use
      cert.serial = UUIDTools::UUID.random_create.to_i #(@@serial += 1)
      cert.subject = subject
      cert.public_key = key.public_key
      cert.not_before = not_before
      cert.not_after = not_before + duration
      #extensions << ["subjectAltName", "URI:http://foo.com/users/dc766130, URI:frcp:dc766130-c822-11e0-901e-000c29f89f7b@foo.com", false]
      unless addresses.empty?
        issuer_cert = issuer ? issuer.to_x509 : cert
        ef = OpenSSL::X509::ExtensionFactory.new
        ef.subject_certificate = cert
        ef.issuer_certificate = issuer_cert
        cert.add_extension(ef.create_extension("subjectAltName", addresses.join(','), false))
        # extensions.each{|oid, value, critical|
          # cert.add_extension(ef.create_extension(oid, value, critical))
        # }
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

    attr_reader :addresses, :addresses_raw, :addresses_string
    attr_reader :subject, :key, :digest

    def initialize(opts)
      if @cert = opts[:cert]
        @subject = @cert.subject
      end
      _extract_addresses(@cert)
      # unless @address = opts[:address]
        # # try to see it it is in cert
        # if @cert
          # @cert.extensions.each do |ext|
            # if ext.oid == 'subjectAltName'
              # @address = ext.value[4 .. -1] # strip off 'URI:'
            # end
          # end
        # end
      # end
      if @key = opts[:key]
        @digest = opts[:digest] || self.class._create_digest
      end
      unless @subject ||= opts[:subject]
        name = opts[:name]
        type = opts[:type]
        domain = opts[:domain]
        @subject = _create_name(name, type, domain)
      end
      #@cert ||= _create_x509_cert(@address, @subject, @key, @digest)[:cert]
      @cert ||= _create_x509_cert(@subject, @key, @digest)[:cert]
    end

    # @param [OpenSSL::PKey::RSA|String] key is most likely the public key of the resource.
    #
    # def create_for(address, name, type, domain = DEF_DOMAIN_NAME, duration = 3600, key = nil)
      # raise ArgumentError, "Address required" unless address
#
      # begin
        # key = OpenSSL::PKey::RSA.new(key) if key && key.is_a?(String)
      # rescue OpenSSL::PKey::RSAError
        # # It might be a SSH pub key, try that
        # key = OmfCommon::Auth::SSHPubKeyConvert.convert(key)
      # end
#
      # cert = self.class.create(address, name, type, domain, self, Time.now, duration, key)
      # CertificateStore.instance.register(cert, address)
      # cert
    # end

    def create_for_resource(resource_id, resource_type, opts = {})
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
