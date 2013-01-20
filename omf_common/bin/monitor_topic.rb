

# Monitor a specific topic and print all observed messages
#

# OMF_VERSIONS = 6.0
require 'omf_common'

OP_MODE = :development

opts = {
  communication: {
    type: :amqp,
    server: 'srv.mytestbed.net'
  },
  eventloop: { type: :em},
  logging: {
    level: 'info'
  }  
}

observed_topic = 'cloud_1'

def observe(tname, comm)
  comm.subscribe(tname) do |topic|
    topic.on_message do |msg|
      puts "#{tname}   <#{msg.type}(#{msg.inform_type})>    #{msg.inspect}"
      msg.each_property do |name, value|
        puts "    #{name}: #{value}"
      end
      puts "------"
      
      if msg.inform_type == 'created'
        #puts ">>>>>> #{msg}"
        observe(msg[:resource_id], comm)
      end
    end
  end
end

OmfCommon.init(OP_MODE, opts) do |el|
  OmfCommon.comm.on_connected do |comm|
    observe(observed_topic, comm)
  end
end