#
DESCR = %{
Broadcast a file to a topic group
}

require 'omf_common'

OP_MODE = :development
$debug = false

opts = {
  communication: {
#    url: 'amqp://srv.mytestbed.net'
  },
  eventloop: { type: :em},
  logging: {
    level: 'info'
  }  
}

file_path = nil
resource_url = nil

op = OptionParser.new
op.banner = "Usage: #{op.program_name} [options]\n#{DESCR}\n"
op.on '-r', '--resource-url URL', "URL of resource" do |url|
  resource_url = url
end
op.on '-f', '--file FILE', "File to broadcast" do |path|
  file_path = path
end
op.on '-d', '--debug', "Set logging to DEBUG level" do
  opts[:logging][:level] = 'debug'
  $debug = true
end
op.on_tail('-h', "--help", "Show this message") { $stderr.puts op; exit }
rest = op.parse(ARGV) || []

unless resource_url && file_path
  $stderr.puts 'Missing --resource-url or --file'
  $stderr.puts op
  exit(-1)
end

r = resource_url.split('/')
resource = r.pop
opts[:communication][:url] = r.join('/')

OmfCommon.init(OP_MODE, opts) do |el|
  OmfCommon.comm.on_connected do |comm|
    comm.broadcast_file(file_path, resource) do |state|
      debug state.inspect
      OmfCommon.eventloop.stop if state[:action] == :done
    end
  end
end