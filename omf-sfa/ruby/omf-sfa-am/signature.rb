
module OMF::GENI::AM
  class Signature

    # The xml _content_ (provided as string) should
    # contain a _Signature_ tag. 
    #
    # Returns a _Signature_ object if valid.
    # Raises exception if not valid
    #
    def self.verify_xml_string(content)
      tf = sig = nil
      begin
        tf = Tempfile.open('omf-am-rpc')
        tf << content
        tf.close
        cmd = "#{@@xmlsec} verify --trusted-pem #{@@root_certs} --print-xml-debug #{tf.path} 2> /dev/null"
        out = []
        #IO.popen("#{cmd} 2>&1") do |so| 
        IO.popen(cmd) do |so| 
          sig = Nokogiri::XML.parse(so)
        end 
        unless (sig.xpath('/VerificationContext')[0]['status'] == 'succeeded')
          raise "Error: Signature doesn't verify\n#{sig.to_xml}"
        end
      ensure
        tf.close! if tf
      end
      return Signature.new(sig)
    end
    
    def initialize(sig_doc)
      @sig_doc = sig_doc
    end

  end # Signature
end # OMF::GENI::AM
