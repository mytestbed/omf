require "omf-common/omfPubSubService"

jid_suffix="10.0.0.200"

puts "TDEBUG - START PUBSUB - #{jid_suffix}"

# Create a Service Helper to interact with the PubSub Server
begin
  @@service = OmfPubSubService.new("aggmgr", "123", jid_suffix)
  # Start our Event Callback, which will process Events from
  # the nodes we will subscribe to
  #debug "TDEBUG - start 1"
  @@service.add_event_callback { |event|
    puts "TDEBUG - New Event - '#{event}'" 
    execute_command(event)
    puts "TDEBUG - Finished Processing Event" 
  }         
rescue Exception => ex
  error "ERROR - start - Creating ServiceHelper - PubSubServer: '#{jid_suffix}' - Error: '#{ex}'"
end

#debug "TDEBUG - start 2"
puts "Connected to PubSub Server: '#{jid_suffix}'"
    
# let the gridservice do this:
@@service.create_pubsub_node("/Domain")
@@service.create_pubsub_node("/Domain/System")
@@service.create_pubsub_node("/Domain/System/10.0.0.1")
@@service.create_pubsub_node("/Domain/System/10.0.0.2")
@@service.create_pubsub_node("/Domain/System/10.0.0.3")
@@service.create_pubsub_node("/Domain/System/10.0.0.4")
@@service.create_pubsub_node("/Domain/System/10.0.0.5")


