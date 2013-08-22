require 'rubygems'
gem 'xmpp4r'
require "xmpp4r"
require "xmpp4r/pubsub"
require "xmpp4r/pubsub/helper/servicehelper.rb"
require "xmpp4r/pubsub/helper/nodebrowser.rb"
require "xmpp4r/pubsub/helper/nodehelper.rb"
require "omf-common/communicator/omfPubSubMessage"
include Jabber

#Jabber::debug=true

#
# This is a class test for pub/sub communication within OMF
#
# Use it inside the Ruby interpreter 'irb'
#
# This is used to:
# - create and delete all the PUBSUB nodes used for the test phase 
# - send arbitry messages to a given PUBSUB node used for the test phase 
# You should also use TestNAListener to make sure that messages were actually sent, 
# thus allows you to really focus on the NA comms. (i.e. you are sure that the PUBSUB server
# is actually doing its job correctly)
#
#
class MyServiceHelper < Jabber::PubSub::ServiceHelper
  #
  # Perform a 'unsubscribe_from' from scratch
  #
  def unsubscribe_from_fixed (node,subid)
    iq = basic_pubsub_query(:set)
    sub = REXML::Element.new('unsubscribe')
    sub.attributes['node'] = node
    sub.attributes['jid'] = @stream.jid.strip.to_s
    sub.attributes['subid']=subid
    iq.pubsub.add(sub)
    ret = false
    @stream.send_with_id(iq) do |reply|
      ret = reply.kind_of?(Jabber::Iq) and reply.type == :result
    end # @stream.send_with_id(iq)
    ret  
  end
end

class PubSubTester

  def initialize(userJID, userPWD, serverJID, serviceJID, listen = true)
    @format = REXML::Formatters::Pretty.new
    @userJID = userJID
    @userPWD = userPWD
    @serverJID = serverJID
    #@serviceJID = serviceJID
    @serviceJID = "pubsub.#{serviceJID}"
    # Processing Q for incoming events
    @queue = Queue.new
    Thread.new {
      while event = @queue.pop
        process_event(event)
      end
    }

    # Create and Connect a Client
    @clientHelper = Jabber::Client.new(@userJID)
    @clientHelper.connect(@serverJID)
    begin
      @clientHelper.register(@userPWD)
    rescue Exception => ex
      if ("#{ex}" != "conflict: ")
        then raise "Failed to register user #{@userJID} - Error: '#{ex}'"
      end
    end
    @clientHelper.auth(@userPWD)
    @clientHelper.send(Jabber::Presence.new)
    puts "\nCONNECT OK - userJID: '#{@userJID}' - serverJID: '#{@serverJID}'\n"

    # Create Service Helper
    @service = MyServiceHelper.new(@clientHelper, @serviceJID)
    puts "\nSERVICE OK - serviceJID: '#{@serviceJID}'\n"
    @browser = Jabber::PubSub::NodeBrowser.new(@clientHelper)
    puts "\nBROWSER OK - serviceJID: '#{@serviceJID}'\n"

    # Start our Event Callback, which will process Events from
    # the nodes we will subscribe to
    @service.add_event_callback { |event|
      if listen 
        @queue << event
      end
    }
  end

  def process_event (event)
    begin
        incomingPubSubNode =  event.first_element("items").attributes['node']
        eventBody = event.first_element("items").first_element("item").first_element("message").first_element("body")
        puts "----"
        puts "RECEIVED : '#{incomingPubSubNode}'"
        puts "FULL MSG : '#{event.to_s}'"
        puts "PAYLOAD  : #{eventBody.to_s}"
        puts "----"
    rescue Exception => ex
      puts "----"
      puts "RAW XMPP EVENT"
      puts "#{event.to_s}"
      puts "----"
      #puts "Error Message: '#{ex}' "
      return
    end
  end

  def send (node, message)
    item = Jabber::PubSub::Item.new
    if message.kind_of?(OmfPubSubMessage)
      payload = message.serialize
    else 
      payload = message
    end
    msg = Jabber::Message.new(nil, payload)
    item.add(msg)
    begin
      @service.publish_item_to("#{node}", item)
    rescue Exception => ex
      puts "Failed sending to '#{node}'"
      puts "Error: '#{ex}'"
      puts "Msg: '#{payload}'"
      return
    end
    puts "Sent msg to '#{node}' - '#{payload}'"
  end

  def newcmd(cmdtype)
    return OmfPubSubMessage.new(cmdtype)
  end

  def create(node)
    @service.create_node(node, Jabber::PubSub::NodeConfig.new(nil,{
        "pubsub#title" => "#{node}",
#        "pubsub#node_type" => "flat",
#        "pubsub#node_type" => "leaf",
        "pubsub#persist_items" => "1",
        "pubsub#max_items" => "1",
        "pubsub#notify_retract" => "0",
        "pubsub#publish_model" => "open"}))
  end 

  def delete(node)
    @service.delete_node(node)
  end 

  def getconfig(node)
    @service.get_config_from(node)
  end 

  def setconfig(node, config)
    @service.set_config_for(node, config)
  end 

  def join(node)
    @service.subscribe_to(node)
  end 

  def leave(node, id)
    @service.unsubscribe_from_fixed(node, id)
  end 

  def listsub()
    list = []
    list = @service.get_subscriptions_from_all_nodes
    list.each { |sub|
      puts "Subscribed to : '#{sub.node}' - '#{sub.subid}'"
    }
    return 1
  end

  def listall(server = @serviceJID)

    # Create and Connect a Client
    #newUserJID = "browse-#{@userJID}"
    #newClientHelper = Jabber::Client.new(newUserJID)
    #newClientHelper.connect(@serverJID)
    #begin
    #  newClientHelper.register(@userPWD)
    #rescue Exception => ex
    #  if ("#{ex}" != "conflict: ")
    #    then raise "Failed to register user #{newUserJID} - Error: '#{ex}'"
    #  end
    #end
    #newClientHelper.auth(@userPWD)
    #newClientHelper.send(Jabber::Presence.new)
    #puts "\nCONNECT OK - userJID: '#{newUserJID}' - serverJID: '#{@serverJID}'\n"

    #browser = Jabber::PubSub::NodeBrowser.new(newClientHelper)
    list = @browser.nodes(@serviceJID)
    puts "-- Server: #{@serviceJID}"
    list.each { |node|
      puts "--   Node: '#{node}'"
    }
    #newClientHelper.close
  end

  def listen
    while 1 do
    end
  end

  def pp(inxml)
    out = String.new
    @format.write(inxml, out)
    puts out
  end

end
