require 'omf_common/auth'

module OmfCommon::Auth
  class Assertion
    attr_reader :content, :iss, :type

    # Parse from a serialised assertion
    #
    def self.parse(str, opts = {})
      opts[:type] ||= 'json'

      case opts[:type]
      when 'json'
        new(JSON.parse(str, symbolize_names: true).merge(type: 'json'))
      end
    end

    # Factory method to generate new assertion
    #
    def self.generate(str, opts = {})
      raise 'Missing iss of assertion' if opts[:iss].nil?

      cert = OmfCommon::Auth::CertificateStore.instance.cert_for(opts[:iss])

      raise "Certifcate of #{opts[:iss]} NOT found" if cert.nil?

      sig = Base64.encode64(cert.key.sign(OpenSSL::Digest::SHA256.new(str), str)).encode('utf-8')

      new(opts.merge(content: str, sig: sig))
    end

    # Verify cert and sig validity
    #
    def verify
      cert = OmfCommon::Auth::CertificateStore.instance.cert_for(@iss)

      # Verify cert
      #
      unless OmfCommon::Auth::CertificateStore.instance.verify(cert)
        warn "Invalid certificate '#{cert.to_s}', NOT signed by CA certs, or its CA cert NOT loaded into cert store."
        return false
      end

      if cert.nil?
        warn "Certifcate of #{@iss} NOT found"
        return false
      end

      # Verify sig
      #
      cert.to_x509.public_key.verify(OpenSSL::Digest::SHA256.new(@content), Base64.decode64(@sig), @content)
    end

    def to_s
      case @type
      when 'json'
        { type: @type, iss: @iss, sig: @sig, content: @content }.to_json
      end
    end

    private

    def initialize(opts = {})
      @type = opts[:type] || 'json'
      @iss = opts[:iss]
      # Signature of assertion content signed by issuer
      @sig = opts[:sig]
      @content = opts[:content]
    end
  end
end
