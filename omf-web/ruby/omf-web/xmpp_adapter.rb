
require 'singleton'
require "omf-common/communicator/xmpp/omfPubSubTransport"


class Tester
  
  def initialize(opts)
    @sliceID = opts[:sliceID]
    @domain = opts[:config][:xmpp][:pubsub_gateway]
    @transport = OMFPubSubTransport.instance
    @transport.init(opts)
    @slice_addr = @transport.get_new_address(:sliceID => @sliceID, :domain => @domain) 
  end
  
  def subscribe(addr = {}, &block)
    xaddr = @transport.get_new_address(addr.merge(:sliceID => @sliceID, :domain => @domain))
    @transport.listen(xaddr, &block)
  end
  
end

opts = {
    :createflag=>true, 
    :sliceID=>"debug", 
    :config => {
      :type => "xmpp", 
      :authenticate_messages => false, 
      :xmpp =>{
        :pubsub_gateway => "maxs-laptop.local", 
        :pubsub_max_retries => 1, 
        :pubsub_user => "debug"
      }
    }
  }

t = Tester.new(opts)
t.subscribe do |m|
  puts "====>>>> #{m.attributes.inspect}"
end

sleep 100
    
