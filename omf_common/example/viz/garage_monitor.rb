# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'omf_oml/table'

class GarageMonitor < OMF::Common::LObject
  OP_MODE = :development

  def initialize(opts)
    @observed_topics = {}

    create_event_table
    Thread.new do
      begin
        sleep 3
        OmfCommon.init(OP_MODE, opts) do |el|
          OmfCommon.comm.on_connected do |comm|
            observe('garage1', comm)
          end
        end
      rescue Exception => ex
        puts "ERROR: #{ex}"
        puts "\t#{ex.backtrace.join("\n\t")}"
      end
    end
    
    
  end
  
  def observe(tname, comm)
    return if (tname.nil? || @observed_topics.key?(tname))
  
    info "Observing '#{tname}'"
    @observed_topics[tname] = true
    comm.subscribe(tname) do |topic|
      topic.on_message do |msg|
        ts = Time.now.strftime('%H:%M:%S')
        src = topic.id
        type = "#{msg.type}(#{msg.itype})"
        msg.each_property do |name, value|
          @evt_table.add_row [ts, src, type, name, value]
        end
        if msg.itype == 'released' && src != :garage1
          @engine_table.add_row [ts, src, -1, -1]
        end
        
        if (msg[:throttle] && msg[:rpm])
          puts "RPM: #{msg[:rpm]}::#{msg[:rpm].class}"
          @engine_table.add_row [ts, src, msg[:throttle], msg[:rpm]]
        end
        observe(msg[:res_id], comm)
      end
    end
  end
  
  
  
  def create_event_table(fake_events = true)
    evt_schema = [:ts, :address, :type, :name, :value]
    @evt_table = OMF::OML::OmlTable.new 'events', evt_schema, :max_size => 500
    OMF::Web.register_datasource @evt_table

    engine_schema = [:ts, :source, [:throttle, :int], [:rpm, :int]]
    @engine_table = OMF::OML::OmlTable.new 'engine', engine_schema, :max_size => 20
    OMF::Web.register_datasource @engine_table.indexed_by(:source), name: 'engine'
  end
end
