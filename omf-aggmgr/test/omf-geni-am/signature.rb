require 'nokogiri'

module OMF; module GENI; module AM
  # This class holds information about the signature
  # over some XML fragment.
  #
  class Signature

    @@root_certs = '~/.gcf/trusted_roots/CATedCACerts.pem'
    @@xmlsec = 'xmlsec1'

    @@x2urn = {
      '/CN=geni//gpo//gcf.authority.sa' => 'URI:urn:publicid:IDN+geni:gpo:gcf+authority+sa'
    }

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
#puts content
        tf << content
        tf.close
        cmd = "#{@@xmlsec} verify --trusted-pem #{@@root_certs} --print-xml-debug #{tf.path} 2> /dev/null"
        out = []
        #IO.popen("#{cmd} 2>&1") do |so| 
        IO.popen(cmd) do |so| 
          sig = Nokogiri::XML.parse(so)
          # File.open('/tmp/sig-debug.xml', 'w') do |f|
          #   f << sig.to_xml
          # end
        end 
        unless (sig.xpath('/VerificationContext')[0]['status'] == 'succeeded')
          raise "Error: Signature doesn't verify\n#{sig.to_xml}"
        end
      ensure
        tf.close! if tf
      end
      return Signature.new(sig)
    end
    
    attr_reader :signer

    def initialize(sig_doc)
      @sig_doc = sig_doc
      signer = @sig_doc.xpath('//SignatureKey//KeyCertificate/SubjectName')[0].content
      # we prefer urns for conformity
      @signer =  @@x2urn[signer] || signer
    end

  end # Signature
end; end; end # OMF::GENI::AM
