require 'nokogiri'
require 'signature'

module OMF; module GENI; module AM
  class Credential

    def self.unmarshall_xml(text)
      cred = Nokogiri::XML.parse(text)
      if (cred.root.name == 'signed-credential') 
        signature = Signature.verify_xml_string(text)
      end
      unless (type_el =  cred.xpath('//credential/type')[0])
        raise "Credential doesn't contain 'type' element"
      end
      case type_el.content
      when "privilege"
        require 'privilege_credential'
        return PrivilegeCredential.new(cred, signature)
      end
      raise "Unknown credential type '#{type_el.content}'"
    end


    
    protected
    def initialize(credential, signature = nil)
      @cred = credential
      @sig = signature
    end

  end # Credential                     
end; end; end # OMF::GENI::AM
