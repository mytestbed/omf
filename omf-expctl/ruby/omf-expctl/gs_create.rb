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
@@service.create_pubsub_node("/Domain/System/10.0.0.6")
@@service.create_pubsub_node("/Domain/System/10.0.0.7")
@@service.create_pubsub_node("/Domain/System/10.0.0.8")
@@service.create_pubsub_node("/Domain/System/10.0.0.9")
@@service.create_pubsub_node("/Domain/System/10.0.0.10")
@@service.create_pubsub_node("/Domain/System/10.0.0.11")
@@service.create_pubsub_node("/Domain/System/10.0.0.12")
@@service.create_pubsub_node("/Domain/System/10.0.0.13")
@@service.create_pubsub_node("/Domain/System/10.0.0.14")
@@service.create_pubsub_node("/Domain/System/10.0.0.15")
@@service.create_pubsub_node("/Domain/System/10.0.0.16")
@@service.create_pubsub_node("/Domain/System/10.0.0.17")
@@service.create_pubsub_node("/Domain/System/10.0.0.18")
@@service.create_pubsub_node("/Domain/System/10.0.0.19")
@@service.create_pubsub_node("/Domain/System/10.0.0.20")
@@service.create_pubsub_node("/Domain/System/10.0.0.21")
@@service.create_pubsub_node("/Domain/System/10.0.0.22")
@@service.create_pubsub_node("/Domain/System/10.0.0.23")
@@service.create_pubsub_node("/Domain/System/10.0.0.24")
@@service.create_pubsub_node("/Domain/System/10.0.0.25")
@@service.create_pubsub_node("/Domain/System/10.0.0.26")
@@service.create_pubsub_node("/Domain/System/10.0.0.27")
@@service.create_pubsub_node("/Domain/System/10.0.0.28")
@@service.create_pubsub_node("/Domain/System/10.0.0.29")
@@service.create_pubsub_node("/Domain/System/10.0.0.30")
@@service.create_pubsub_node("/Domain/System/10.0.0.31")
@@service.create_pubsub_node("/Domain/System/10.0.0.32")
@@service.create_pubsub_node("/Domain/System/10.0.0.33")
@@service.create_pubsub_node("/Domain/System/10.0.0.34")
@@service.create_pubsub_node("/Domain/System/10.0.0.35")
@@service.create_pubsub_node("/Domain/System/10.0.0.36")
@@service.create_pubsub_node("/Domain/System/10.0.0.37")
@@service.create_pubsub_node("/Domain/System/10.0.0.38")



