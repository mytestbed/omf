# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'amqp'
require 'omf_common/comm/amqp/amqp_topic'
#require 'omf_common/comm/monkey_patches'

module OmfCommon
  class Comm
    class AMQP
      class Communicator < OmfCommon::Comm

        # def initialize(opts = {})
          # # ignore arguments
        # end

        attr_reader :channel

        # Initialize comms layer
        #
        def init(opts = {})
          @opts = {
            #:ssl (Hash) TLS (SSL) parameters to use.
            heartbeat: 20, # (Fixnum) - default: 0 Connection heartbeat, in seconds. 0 means no heartbeat. Can also be configured server-side starting with RabbitMQ 3.0.
            #:on_tcp_connection_failure (#call) - A callable object that will be run if connection to server fails
            #:on_possible_authentication_failure (#call) - A callable object that will be run if authentication fails (see Authentication failure section)
            reconnect_delay: 20 # (Fixnum) - Delay in seconds before attempting reconnect on detected failure
          }.merge(opts)

          unless (@url = @opts.delete(:url))
            raise "Missing 'url' option for AQMP layer"
          end
          @address_prefix = @url + '/frcp.'
          _connect()
          super
        end

        def conn_info
          { proto: :amqp, user: ::AMQP.settings[:user], domain: ::AMQP.settings[:host] }
        end

        def string_to_topic_address(a_string)
          @address_prefix+a_string
        end

        # Shut down comms layer
        def disconnect(opts = {})
          info "Disconnecting..."
        end

        # TODO: Should be thread safe and check if already connected
        def on_connected(&block)
          @on_connected_procs << block
        end

        # register callbacks to be called when the underlying AMQP layer
        # needs to reconnect to the AMQP server. This may require some additional
        # repairs. If 'block' is nil, the callback is removed
        #
        def on_reconnect(key, &block)
          if block.nil?
            @on_reconnect.delete(key)
          else
            @on_reconnect[key] = block
          end
        end

        # Create a new pubsub topic with additional configuration
        #
        # @param [String] topic Pubsub topic name
        def create_topic(topic, opts = {})
          raise "Topic can't be nil or empty" if topic.nil? || topic.to_s.empty?
          opts = opts.dup
          opts[:communicator] = self
          topic = topic.to_s
          if topic.start_with? 'amqp:'
            # absolute address
            unless topic.start_with? @address_prefix
              raise "Cannot subscribe to a topic from different domain (#{topic}) - #{@address_prefix}"
            end
            opts[:address] = topic
            topic = topic.split(@address_prefix).last
          else
            opts[:address] = @address_prefix + topic
          end
          OmfCommon::Comm::AMQP::Topic.create(topic, opts)
        end

        # Delete a pubsub topic
        #
        # @param [String] topic Pubsub topic name
        def delete_topic(topic, &block)
          # FIXME CommProvider?
          if t = OmfCommon::CommProvider::AMQP::Topic.find(topic)
            t.release
          else
            warn "Attempt to delete unknown topic '#{topic}"
          end
        end

        def broadcast_file(file_path, topic_name = nil, opts = {}, &block)
          topic_name ||= SecureRandom.uuid
          require 'omf_common/comm/amqp/amqp_file_transfer'
          OmfCommon::Comm::AMQP::FileBroadcaster.new(file_path, @channel, topic_name, opts, &block)
          "bdcst:#{@address_prefix + topic_name}"
        end

        def receive_file(topic_url, file_path = nil, opts = {}, &block)
          if topic_url.start_with? @address_prefix
            topic_url = topic_url[@address_prefix.length .. -1]
          end
          require 'omf_common/comm/amqp/amqp_file_transfer'
          file_path ||= File.join(Dir.tmpdir, Dir::Tmpname.make_tmpname('bdcast', '.xxx'))
          FileReceiver.new(file_path, @channel, topic_url, opts, &block)
        end

        private
        def initialize(opts = {})
          @on_connected_procs = []
          @on_reconnect = {}
          super
        end

        def _connect()
          begin
            last_reported_timestamp = nil
            @session = ::AMQP.connect(@url, @opts) do |connection|
              connection.on_tcp_connection_loss do |conn, settings|
                now = Time.now
                if last_reported_timestamp == nil || (now - last_reported_timestamp) > 60
                  warn "Lost connectivity. Trying to reconnect..."
                  last_reported_timestamp = now
                end
                _reconnect(conn)
              end
              @channel  = ::AMQP::Channel.new(connection)
              @channel.auto_recovery = true

              @on_connected_procs.each do |proc|
                proc.arity == 1 ? proc.call(self) : proc.call
              end

              OmfCommon.eventloop.on_stop do
                connection.close
              end
            end

            rec_delay = @opts[:reconnect_delay]
            @session.on_tcp_connection_failure do
              warn "Cannot connect to AMQP server '#{@url}'. Attempt to retry in #{rec_delay} sec"
              @session = nil
              OmfCommon.eventloop.after(rec_delay) do
                info 'Retrying'
                _connect
              end
            end
            # @session.on_tcp_connection_loss do
              # _reconnect "Appear to have lost tcp connection. Attempt to reconnect in #{rec_delay} sec"
            # end
            @session.on_skipped_heartbeats do
              info '... on_skipped_heartbeats!'
              #_reconnect "Appear to have lost heartbeat. Attempt to reconnect in #{rec_delay} sec"
            end
            @session.on_recovery do
              info 'Recovered!'
              last_reported_timestamp = nil
              @on_reconnect.values.each do |block|
                block.call()
              end
            end
            true
          rescue Exception => ex
            delay = @opts[:reconnect_delay]
            warn "Connecting AMQP failed, will retry in #{delay} (#{ex})"
            OmfCommon.eventloop.after(delay) do
              if _connect
                info 'Reconnection suceeded'
              end
            end
            false
          end
        end

        def _reconnect(conn)
          begin
            conn.reconnect(false, 2)
          rescue Exception => ex
            delay = @opts[:reconnect_delay]
            warn "Reconnect AMQP failed, will retry in #{delay} (#{ex})"
            OmfCommon.eventloop.after(delay) do
              info 'Reconnecting'
              _reconnect(conn)
            end
          end
        end

      end
    end
  end
end
