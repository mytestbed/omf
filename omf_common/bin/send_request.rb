

# Send a request and print out reply
#

# OMF_VERSIONS = 6.0
require 'omf_common'

OP_MODE = :development

opts = {
  communication: {
#    url: 'amqp://srv.mytestbed.net'
  },
  eventloop: { type: :em},
  logging: {
    level: 'info'
  }  
}

resource_url = nil

op = OptionParser.new
op.banner = "Usage: #{op.program_name} [options] prop1 prop2 ..."
op.on '-r', '--resource-url URL', "URL of resource" do |url|
  resource_url = url
end
op.on_tail('-h', "--help", "Show this message") { $stderr.puts op; exit }
req_properties = op.parse(ARGV) || []

unless resource_url
  $stderr.puts 'Missing --resource-url'
  $stderr.puts op
  exit(-1)
end

r = resource_url.split('/')
resource = r.pop
opts[:communication][:url] = r.join('/')
puts opts.inspect
puts resource.inspect
puts req_properties.inspect


OmfCommon.init(OP_MODE, opts) do |el|
  OmfCommon.comm.on_connected do |comm|
    comm.subscribe(resource) do |topic|
      topic.request(req_properties) do |msg|
        puts ">>> REPLY #{msg.inspect}"
      end
    end
  end
end