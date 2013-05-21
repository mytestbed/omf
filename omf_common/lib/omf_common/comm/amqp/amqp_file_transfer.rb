# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'set'
require 'monitor'

module OmfCommon
  class Comm::AMQP
    
    # Distributes a local file to a set of receivers subscribed to the same 
    # topic but may join a various stages.
    #
    class FileBroadcaster
      include MonitorMixin
      
      DEF_CHUNK_SIZE = 2**16
      DEF_IDLE_TIME = 60
      
      # @param topic[String] Name of topic to send file to
      # @param file_path[String] Path to a local file
      # @param opts[Hash]
      #   :chunk_size Max size of data chunk to send
      #   :idle_time Min. time in sec to close down broadcaster after having sent last chunk
      #
      def initialize(file_path, channel, topic, opts = {}, &block)
        super() # init monitor mixin
        @block = block
        unless File.readable?(file_path)
          raise "Can't read file '#{file_path}'"
        end
        @mime_type = `file -b --mime-type #{file_path}`.strip
        unless $?.success?
          raise "Can't determine file's mime-type (#{$?})" 
        end
        @file_path = file_path 
        f = File.open(file_path, 'rb')
        chunk_size = opts[:chunk_size] || DEF_CHUNK_SIZE
        chunk_count = (f.size / chunk_size) + 1
        
        @outstanding_chunks = Set.new
        @running = true
        @semaphore = new_cond()
        idle_time = opts[:idle_time] || DEF_IDLE_TIME
        
        #chunk_count.times.each {|i| @outstanding_chunks << i}

        exchange = channel.topic(topic, :auto_delete => true)
        OmfCommon.eventloop.defer do
          _send(f, chunk_size, chunk_count, exchange, idle_time)
        end
        
        control_topic = "#{topic}_control"
        control_exchange = channel.topic(control_topic, :auto_delete => true)
        channel.queue("", :exclusive => false) do |queue|
          queue.bind(control_exchange)
          debug "Subscribing to control channel '#{control_topic}'"
          queue.subscribe do |headers, payload|
            hdrs = headers.headers
            debug "Incoming control message '#{hdrs}'"
            from = hdrs['request_from']
            from = 0 if from < 0
            to = hdrs['request_to']
            to = chunk_count - 1 if !to || to >= chunk_count
            synchronize do
              (from .. to).each { |i| @outstanding_chunks << i}
              @semaphore.signal
            end
          end
          @control_queue = queue
        end
      end
      
      def _send(f, chunk_size, chunk_count, exchange, idle_time)
        chunks_to_send = nil
        @sent_chunk = false
        _wait_for_closedown(idle_time)
        loop do
          synchronize do
            @semaphore.wait_while { @outstanding_chunks.empty? && @running }
            return unless @running # done!
            chunks_to_send = @outstanding_chunks.to_a
          end
          
          chunks_to_send.each do |chunk_id|
            #sleep 3
            synchronize do
              @outstanding_chunks.delete(chunk_id)
              @sent_chunk = true
            end
            offset = chunk_id * chunk_size
            f.seek(offset, IO::SEEK_SET)
            chunk = f.read(chunk_size)
            payload = Base64.encode64(chunk)
            headers = {chunk_id: chunk_id, chunk_count: chunk_count, chunk_offset: offset, 
                        chunk_size: payload.size, 
                        path: f.path, file_size: f.size, mime_type: @mime_type}
            debug "Sending chunk #{chunk_id}"
            exchange.publish(payload, {headers: headers})
          end
        end
      end
      
      def _wait_for_closedown(idle_time)
        OmfCommon.eventloop.after(idle_time) do
          done = false
          synchronize do
            done = !@sent_chunk && @outstanding_chunks.empty?
            @sent_chunk = false
          end
          if done
            @control_queue.unsubscribe if @control_queue
            @block.call({action: :done}) if @block
          else
            # there was activity in last interval, wait a bit longer
            _wait_for_closedown(idle_time)
          end
        end
      end        
    end
    
    # Receives a file broadcast on 'topic' and stores it in a local file.
    # Optionally, it can report on progress through a provided block.
    #
    class FileReceiver
      include MonitorMixin
      
      WAIT_BEFORE_REQUESTING = 2
      WAIT_BEFORE_REQUESTING_EVERYTHING = 3 * WAIT_BEFORE_REQUESTING
      
      # @param topic[String] Name of topic to receive file on
      # @param file_path[String] Path to a local file
      # @param opts[Hash]
      # @param block Called on progress. 
      #
      def initialize(file_path, channel, topic, opts = {}, &block)
        super() # init monitor mixin
        f = File.open(file_path, 'wb')
        @running = false
        @received_chunks = false
        @outstanding_chunks = Set.new
        @all_requested = false # set to true if we encountered a request for ALL (no 'to')
        @requested_chunks = Set.new
        @received_anything = false
        
        control_topic = "#{topic}_control"
        @control_exchange = channel.topic(control_topic, :auto_delete => true)
        channel.queue("", :exclusive => false) do |queue|
          queue.bind(@control_exchange)
          debug "Subscribing to control topic '#{control_topic}'"
          queue.subscribe do |headers, payload|
            hdrs = headers.headers
            debug "Incoming control message '#{hdrs}'"
            from = hdrs['request_from']
            to = hdrs['request_to']
            synchronize do
              if to
                (from .. to).each { |i| @requested_chunks << i}
              else
                debug "Observed request for everything"
                @all_requested = true
                @nothing_received = -1 * WAIT_BEFORE_REQUESTING # Throttle our own desire to request everything
              end
            end
          end
          @control_queue = queue
        end

        @nothing_received = WAIT_BEFORE_REQUESTING_EVERYTHING - 2 * WAIT_BEFORE_REQUESTING

        data_exchange = channel.topic(topic, :auto_delete => true)
        channel.queue("", :exclusive => false) do |queue|
          queue.bind(data_exchange)
          queue.subscribe do |headers, payload|
            synchronize do
              @received_chunks = true
            end
            hdrs = headers.headers
            chunk_id = hdrs['chunk_id']
            chunk_offset = hdrs['chunk_offset']
            chunk_count = hdrs['chunk_count']
            unless chunk_id && chunk_offset && chunk_count
              debug "Received message with missing 'chunk_id' or 'chunk_offset' header information (#{hdrs})"
            end
            unless @received_anything
              @outstanding_chunks = chunk_count.times.to_set
              synchronize do 
                @running = true 
                @received_anything = true
              end
            end
            next unless @outstanding_chunks.include?(chunk_id)

            debug "Receiving chunk #{chunk_id}"
            f.seek(chunk_offset, IO::SEEK_SET)
            f.write(Base64.decode64(payload))
            @outstanding_chunks.delete(chunk_id)
            received = chunk_count - @outstanding_chunks.size
            if block
              block.call({action: :progress, received: received, progress: 1.0 * received / chunk_count, total: chunk_count})
            end
            
            if @outstanding_chunks.empty?
              # got everything
              f.close
              queue.unsubscribe
              @control_queue.unsubscribe if @control_queue
              @timer.cancel
              synchronize { @running = false }
              debug "Fully received #{file_path}"
              if block
                block.call({action: :done, size: hdrs['file_size'], 
                  path: file_path, mime_type: hdrs['mime_type'], 
                  received: chunk_count})
              end           
            end
          end
        end
        
        @timer = OmfCommon.eventloop.every(WAIT_BEFORE_REQUESTING) do
          from = to = nil
          synchronize do
            #puts "RUNNING: #{@running}"
            #break unless @running
            if @received_chunks
              @received_chunks = false
              @nothing_received = 0
              break # ok there is still action
            else
              # nothing happened, so let's ask for something
              if (@nothing_received += WAIT_BEFORE_REQUESTING) >= WAIT_BEFORE_REQUESTING_EVERYTHING
                # something stuck here, let's re-ask for everything
                from = 0
                @nothing_received = 0
              else
                # ask_for is the set of chunks we are still missing but haven't asked for              
                ask_for = @outstanding_chunks - @requested_chunks
                break if ask_for.empty? # ok, someone already asked, so better wait
                
                # Ask for a single span of consecutive chunks 
                aa = ask_for.to_a.sort
                from = to = aa[0]
                aa.each.with_index do |e, i| 
                  break unless (from + i == e) 
                  to = e
                  @requested_chunks << e
                end
              end
              
            end
          end
          if from
            headers = {request_from: from}
            headers[:request_to] = to if to  # if nil, ask for everything
            @control_exchange.publish(nil, {headers: headers})
          end
        end 
        
      end
    end
    
  end
end
