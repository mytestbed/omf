#
DESCR = %{
Send a request to a specific resource (topic) and print out any replies.

Any additional command line arguments are interpreted as limiting the request
to those, otherwise all properties are requested.
}

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
op.banner = "Usage: #{op.program_name} [options] prop1 prop2 ...\n#{DESCR}\n"
op.on '-r', '--resource-url URL', "URL of resource" do |url|
  resource_url = url
end
op.on '-d', '--debug', "Set logging to DEBUG level" do
  opts[:logging][:level] = 'debug'
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

OmfCommon.init(OP_MODE, opts) do |el|
  OmfCommon.comm.on_connected do |comm|
    comm.subscribe(resource) do |topic|
      topic.request(req_properties) do |msg|
        puts "#{tname}   <#{msg.type}(#{msg.inform_type})>    #{msg.inspect}"
        msg.each_property do |name, value|
          puts "    #{name}: #{value}"
        end
        puts "------"
      end
    end
  end
end