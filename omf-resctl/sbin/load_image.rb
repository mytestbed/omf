#!/usr/bin/env ruby1.8

require 'omf-common/mobject'
require 'omf-common/execApp'
require 'oml'

class MpProgress < OML::MPBase
  name :progress
  param :exp_id
  param :task
  param :progress, :type => :long
end

class MpStatus < OML::MPBase
  name :status
  param :exp_id
  param :task
  param :msg_type
  param :message
end


class Observer < MObject
  attr_reader :progress

  def onAppEvent(type, appId, message = "")
begin
    debug "onAppEvent: type: #{type}, id: #{appId} msg: '#{message}'"
    if type.to_sym == :stdout
      if m = @regexp.match(message)
        @progress = m[1].to_i * @scale
        debug "progress: #{@progress}%"
        MpProgress.inject $exp_id, appId, @progress
puts "RETUN"
        return
      end
    end
    MpStatus.inject $exp_id, appId, type, "<#{message}>"
    if /DONE/.match type
      @mutex.synchronize do
        @blocker.signal
      end
    end
rescue Exception => ex
  puts "ERROR: #{ex}"
end
puts "RETUN"
  end

  def wait()
    @mutex.synchronize do
      @blocker.wait @mutex
    end
  end

  def initialize(regexp, scale = 1)
    @regexp = regexp
    @scale = scale

    @progress = 0
    @mutex = Mutex.new
    @blocker = ConditionVariable.new
  end
end

require 'optparse'

if_addr = nil
mc_addr = "224.0.0.1"
mc_port = 7000
device = '/dev/sda'
oml_url = nil
$exp_id = nil

opts = OptionParser.new
opts.banner = "\nLoad image onto node and fix up file system afterwards"

opts.on("-i", '--if_addr ADDR', "IP address of receiving interface") { |p| if_addr = p }
opts.on("-m", '--mc_addr ADDR', "Frisbee's multicast address [#{mc_addr}]") { |m| mc_addr = m }
opts.on("-p", '--port PORT', "Frisbee's port number [#{mc_port}]") { |p| mc_port = p }
opts.on("-d", '--device DEVICE', "Device to image [#{device}]") { |d| device  = d }
opts.on("-o", '--oml OML_URL', "OML URL") { |u| oml_url = u }
opts.on("-e", '--exp-id EXP_ID', "Experiment ID") { |e| $exp_id = e }

opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }
opts.parse(ARGV)

unless if_addr && oml_url && $exp_id
  MObject.fatal :main, "Missing arguments"
  exit
end

oml_opts = {:exp_id => 'image_load', :node_id => 'n1', :app_name => 'img_load'}
if oml_url.start_with? 'file:'
  proto, file = oml_url.split(':')
  oml_opts[:file] = file
elsif oml_url.start_with? 'tcp:'
  #tcp:norbit.npc.nicta.com.au:3003
  proto, host, port = oml_url.split(':')
  oml_opts[:server_name] = host
  oml_opts[:server_port] = port
else
  MObject.fatal :main, "Unknown OML url: '#{oml_url}'"
  exit -1
end

OML::init oml_opts
MpProgress.inject $exp_id, :load, 0

fcmd = "frisbee -i #{if_addr} -m #{mc_addr} -p #{mc_port} #{device}"
ExecApp.new :frisbee, o = Observer.new(/[^0-9]*([0-9]+)\%/), fcmd
o.wait

rcmd = "/usr/sbin/growpart-5.4.sh #{device}"
ExecApp.new :resize, o = Observer.new(/^([0-9]+)->/, 10), rcmd
o.wait

MpProgress.inject $exp_id, :load, 100
MObject.info 'Done'

