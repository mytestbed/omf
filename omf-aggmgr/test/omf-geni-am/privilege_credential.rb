require 'nokogiri'
require 'time'

module OMF; module GENI; module AM
  class PrivilegeCredential < Credential

    attr_reader :target, :issuer

    # Return true, if this credential provides owner with
    # _privilege_
    #
    def allowed?(privilege)
      valid? && @privileges[privilege] == true
    end

    # Return true if credential is valid right now
    #
    def valid?
      @expires > Time.now
    end

    def initialize(credential, signature)
      super

      @expires = Time.parse(credential.xpath('//expires')[0].content)
      if @expires < Time.now
        #raise "Credential already expired"
      end

      @issuer = credential.xpath('//owner_urn')[0].content
      @target = credential.xpath('//target_urn')[0].content

      #owner_cert = parse_cert('owner_id')
      #target_cert = parse_cert('target_id')

      @privileges = {}
      credential.xpath('//privilege/name').each do |p|
        @privileges[p.content.downcase.to_sym] = true
      end
      #puts @cred.to_xml
    end

    private

    # Return Cert under xml element _el_name_
    def parse_cert(el_name)
      unless (el = @cred.xpath("//#{el_name}")[0])
        raise "Missing '#{el_name}' in Privilege Credential"
      end
      OpenSSL::X509::Certificate.new(el.content)
    end

  end # PrivilegeCredential                     
end; end; end # OMF::GENI::AM
