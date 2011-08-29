require 'nokogiri'

module OMF::SFA::AM
  class Credential

    @@root_certs = '~/.gcf/trusted_roots/CATedCACerts.pem'
    @@xmlsec = 'xmlsec1'

    def self.unmarshall(text)
      cred = Nokogiri::XML.parse(text)
#      puts @doc.to_xml
      unless (type_el =  cred.xpath('//credential/type')[0])
        raise "Credential doesn't contain 'type' element"
      end
      case type_el.content
      when "privilege"
        return true
      end
      raise "Unknown credential type '#{type_el.content}'"
    end

    protected
    def initialize(text = nil)
      if (text)
        verify_xml(text)
      end
    end

    # The xml _content_ (provided as string) should
    # contain a _Signature_ tag. 
    #
    # Returns true if signature is valid, false otherwise
    #
    def verify_xml(content)
      tf = nil
      begin
        tf = Tempfile.open('omf-am-rpc')
        tf << content
        tf.close
        cmd = "#{@@xmlsec} verify --trusted-pem #{@@root_certs} --print-xml-debug #{tf.path} 2> /dev/null"
        out = []
        #IO.popen("#{cmd} 2>&1") do |so| 
        IO.popen(cmd) do |so| 
          @signature = Nokogiri::XML.parse(so)
        end 
        unless (@signature.xpath('/VerificationContext')[0]['status'] == 'succeeded')
          raise "Error: Signature doesn't verify\n#{@signature.to_xml}"
        end
      ensure
        tf.close! if tf
      end
    end
    
  end # Credential                     
end # OMF::GENI::AM
