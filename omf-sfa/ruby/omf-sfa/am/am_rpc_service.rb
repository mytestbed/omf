
require 'nokogiri'    
require 'time'
require 'zlib'
require 'base64'
require 'openssl'
#require 'xmlsec'
require 'tempfile'
require 'xmlrpc/parser'
require 'omf-common/mobject2'

require 'omf_sfa_am'

require 'omf-sfa-am/am_api'
require 'omf-sfa-am/credential'
  
module OMF::SFA::AM
  
  class AbstractService < Rack::RPC::Server

    # This defines a method to declare the service methods and all their 
    # parameters.
    #
    def self.implement(api)
      @@mappings ||= {}
      api.api_description.each do |m|
        wrapper_name = "_wrapper_#{m.method_name}".to_sym
        self.send(:define_method, wrapper_name) do |*args|
          self.class.hooks[:before].each do |command| 
            command.call(self) if command.callable?(m.method_name)
          end
          out = self.send(m.method_name, *args)
          self.class.hooks[:after].each do |command| 
            command.call(self) if command.callable?(m.method_name)
          end
          out
        end
        #puts "API: map #{m.rpc_name} to #{wrapper_name}"
        @@mappings[m.rpc_name.to_s] = wrapper_name
      end
    end
    
    def self.rpc(mappings = nil)
      raise "Unexpected argument '#{mappings}' for rpc" if mappings
      @@mappings
    end
  end # AbstractService
  
  class NotAuthorizedException < XMLRPC::FaultException; end
  
  class AMService < AbstractService
    include OMF::Common::Loggable
    
    #implement ServiceAPI
    implement AMServiceAPI

    def get_version
      debug 'GetVersion'
      {
        :geni_api => 1,
        :omf_am => "0.1",
        :ad_rspec_versions => [{ 
          :type => 'ProtoGENI',
          :version => '2',
          :namespace => 'http://www.protogeni.net/resources/rspec/2',
          :schema => 'http://www.protogeni.net/resources/rspec/2/ad.xsd',
          :extensions => []
        }]
      }
    end
  
    def list_resources(credentials, options)
      check_credentials(:ListResources, credentials)
      debug 'CreateSliver: Options: ', options.inspect
      
      only_available = options["geni_available"]
      compressed = options["geni_compressed"]
      slice_urn = options["geni_slice_urn"]
  
      res = get_resources(slice_urn, only_available).to_xml
      if compressed
        res = Base64.encode64(Zlib::Deflate.deflate(res))
      end
      res
    end
  
    def create_sliver(slice_urn, credentials, rspec, users)
      check_credentials(:CreateSliver, credentials)
      debug 'CreateSliver: SICE URN: ', slice_urn, ' RSPEC: ', rspec, ' USERS: ', users
      rspec
    end
  
    def sliver_status(slice_urn, credentials)
      check_credentials(:SliverStatus, credentials)
      
      debug('SliverStatus for ', slice_urn)
      
      status = {}
      status['geni_urn'] = slice_urn
      status['geni_status'] = 'ready'
      status['geni_error'] =  ""
      rs = status['geni_resources'] = []
      rs << {
        'geni_urn'=> "SSSS",
        'geni_status' => 'ready',
        'geni_error' => ""
      }
  
      status
    end
  
    def renew_sliver(slice_urn, credentials, expiration_time)
      check_credentials(:RenewSliver, credentials)
      true
    end
  
    def delete_sliver(slice_urn, credentials)
      check_credentials(:DeleteSliver, credentials)
      puts "SLICE URN: #{slice_urn}"
      true
    end
  
    def shutdown_sliver(slice_urn, credentials)
      check_credentials(:Shutdown, credentials)
      puts "SLICE URN: #{slice_urn}"
      true
    end
    
    private 
  
    def get_resources(slice_urn, available_only)
      l = OMF::SFA::Resource::Link.create()
      n1 = OMF::SFA::Resource::Node.create()
      i1 = OMF::SFA::Resource::Interface.create(:node => n1, :network => l)
      n2 = OMF::SFA::Resource::Node.create()
      i2 = OMF::SFA::Resource::Interface.create(:node => n2, :network => l)
      OMF::SFA::Resource::Component.sfa_advertisement_xml([l, n1, n2])
    end



def create_link()
  l = Link.create()
  
  n = Node.first  

      p = 'urn:publicid:IDN+am1.mytestbed.net+'
      Nokogiri::XML::Builder.new do |xml|
        now = Time.now
        xml.rspec('xmlns' => 'http://www.protogeni.net/resources/rspec/0.1',
                  'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                  'generated' => now.iso8601,
                  'valid_until' => (now + 86400).iso8601,
                  'type' => 'advertisement'
                  ) do
          xml.resource('component_manager_uuid' => p + 'am',
                   'component_name' => 'pc1',
                   'component_uuid' => p + 'node+pc1'
                   ) do
            xml.available "true"
            xml.exclusive "true"
            xml.interface('component_id' => p + 'interface+pc1:eth0')
          end
        end
      end
    end
  
    # Throws exception if _credentials_ are *not* sufficient for _action_
    #
    def check_credentials(action, credentials)
      peer_cert_s = @request.env['rack.peer_cert']
      raise "Missing peer cert" unless peer_cert_s
      peer_cert = OpenSSL::X509::Certificate.new(peer_cert_s)
      #puts "SEC IN ********************"
      #puts peer_cert.inspect 
      #puts 
      begin 
      c = Credential.unmarshall(credentials[0])
      rescue Exception => ex
        puts "EX: #{ex}\n#{ex.backtrace.join("\n")}"
      end
      #puts "SEC OUT ********************"
  
      #raise NotAuthorizedException.new(99, 'Insufficient credentials')
    end
    
  end # AMService
  
end # module



