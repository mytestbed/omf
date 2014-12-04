require 'omf_common/auth'

module OmfCommon::Auth
  class Assertion
    attr_reader :content, :iss, :type

    def self.parse(str, opts = { type: 'json' })
      case opts[:type]
      when 'json'
        new(JSON.parse(str, symbolize_names: true).merge(type: 'json'))
      end
    end

    def initialize(opts = {})
      @type = opts[:type] || 'json'
      @iss = opts[:iss]
      # Signature of assertion content signed by issuer
      @sig = opts[:sig]
      @content = opts[:content]
    end

    def verify
      # Verify cert
      # Verify sig
      true
    end

    def to_s
      case @type
      when 'json'
        { type: @type, iss: @iss, sig: @sig, content: @content }.to_json
      end
    end
  end
end
