# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'hashie'
require 'singleton'
require 'zlib'
require 'monitor'

module OmfEc
  # Experiment class to hold relevant state information
  #
  class Experiment
    include Singleton

    include MonitorMixin

    attr_accessor :name, :sliceID, :oml_uri, :js_url, :ss_url, :job_url, :job_mps, :app_definitions, :property, :cmdline_properties, :show_graph, :nodes, :assertion
    attr_reader :groups, :sub_groups

    # MP only used for injecting metadata
    class MetaData < OML4R::MPBase
      name :meta_data

      # TODO: Should we use the meta data functionality - not sure if it is working right now
      param :domain, type: :string
      param :key, type: :string
      param :value, type: :string
    end

    def initialize
      super
      @id = Time.now.utc.iso8601(3)
      @sliceID = nil
      @state ||= Hashie::Mash.new #TODO: we need to keep history of all the events and not ovewrite them
      @groups ||= []
      @nodes ||= []
      @events ||= []
      @app_definitions ||= Hash.new
      @sub_groups ||= []
      @cmdline_properties ||= Hash.new
      @show_graph = false
      @js_url = nil
      @job_url = nil
      @job_mps = {}
      @ss_url = nil
    end

    def state
      @state.values
    end

    def property
      return ExperimentProperty
    end

    def add_property(name, value = nil, description = nil)
      override_value = @cmdline_properties[name.to_s.to_sym]
      value = override_value unless override_value.nil?
      ExperimentProperty.create(name, value, description)
    end

    def resource_state(address)
      @state[address]
    end

    alias_method :resource, :resource_state

    def resource_by_hrn(hrn)
      @state[hrn]
    end

    def add_or_update_resource_state(name, opts = {})
      self.synchronize do
        res = resource_state(name)
        if res
          opts.each do |key, value|
            if value.class == Array
              # Merge array values
              res[key] ||= []
              res[key] += value
              res[key].uniq!
            elsif value.kind_of? Hash
              # Merge hash values
              res[key] ||= {}
              res[key].merge!(value)
            else
              # Overwrite otherwise
              res[key] = value
            end
          end
        else
          debug "Newly discovered resource >> #{name}"
          #res = Hashie::Mash.new({ address: name }).merge(opts)
          opts[:address] = name
          @state[name] = opts

          # Re send membership configure
          #planned_groups = groups_by_res(name)

          #unless planned_groups.empty?
          #  OmfEc.subscribe_and_monitor(name) do |res|
          #    info "Config #{name} to join #{planned_groups.map(&:name).join(', ')}"
          #    res.configure({ membership: planned_groups.map(&:address) }, { assert: OmfEc.experiment.assertion } )
          #  end
          #end
        end
      end
    end

    alias_method :add_resource, :add_or_update_resource_state

    # Find all groups a given resource belongs to
    #
    def groups_by_res(res_addr)
      groups.find_all { |g| g.members.values.include?(res_addr) }
    end

    def sub_group(name)
      @sub_groups.find { |v| v == name }
    end

    def add_sub_group(name)
      self.synchronize do
        @sub_groups << name unless @sub_groups.include?(name)
      end
    end

    def group(name)
      groups.find { |v| v.name == name }
    end

    def add_group(group)
      self.synchronize do
        raise ArgumentError, "Expect Group object, got #{group.inspect}" unless group.kind_of? OmfEc::Group
        @groups << group unless group(group.name)
      end
    end

    def each_group(&block)
      if block
        groups.each { |g| block.call(g) }
      else
        groups
      end
    end

    def all_groups?(&block)
      !groups.empty? && groups.all? { |g| block ? block.call(g) : g }
    end

    def event(name)
      @events.find { |v| v[:name] == name || v[:aliases].include?(name) }
    end

    def add_event(name, opts, trigger)
      self.synchronize do
        warn "Event '#{name}' has already been defined. Overwriting it now." if event(name)
        @events.delete_if { |e| e[:name] == name }
        @events << { name: name, trigger: trigger, aliases: [] }.merge(opts)
        add_periodic_event(event(name)) if opts[:every]
      end
    end

    def clear_events
      self.synchronize do
        @events.each do |e|
          e[:periodic_timer].cancel if e[:periodic_timer]
        end
        @events = []
      end
    end

    # Unique experiment id
    def id
      @name || @id
    end

    # Unique experiment id (Class method)
    def self.ID
      instance.id
    end

    # Unique slice id (Class method)
    def self.sliceID
      instance.sliceID
    end

    # Parsing user defined events, checking conditions against internal state, and execute callbacks if triggered
    def process_events
      self.synchronize do
        @events.find_all { |v| v[:every].nil? }.each do |event|
          eval_trigger(event)
        end
      end
    end

    def add_periodic_event(event)
      event[:periodic_timer] = OmfCommon.el.every(event[:every]) do
        self.synchronize do
          eval_trigger(event)
        end
      end
    end

    def eval_trigger(event)
      if event[:callbacks] && !event[:callbacks].empty? && event[:trigger].call(state)
        # Periodic check event
        event[:periodic_timer].cancel if event[:periodic_timer] && event[:consume_event]

        @events.delete(event) if event[:consume_event]
        event_names = ([event[:name]] + event[:aliases]).join(', ')
        info "Event triggered: '#{event_names}'"

        # Last in first serve callbacks
        event[:callbacks].reverse.each do |callback|
          callback.call
        end
      end
    end

    def mp_table_names
      {}.tap do |m_t_n|
        groups.map(&:app_contexts).flatten.map(&:mp_table_names).each do |v|
          m_t_n.merge!(v)
        end
      end
    end

    def log_metadata(key, value, domain = 'sys')
      #MetaData.inject_metadata(key.to_s, value.to_s)
      MetaData.inject(domain.to_s, key.to_s, value.to_s)
    end

    # Archive OEDL content to OML db
    def archive_oedl(script_name)
      log_metadata(
        script_name,
        Base64.encode64(Zlib::Deflate.deflate(File.read(script_name))),
        "oedl_content"
      )
    end

    # If EC is launched with --job-service setup, then it needs to
    # create a job entry for this experiment trial
    # Do nothing if:
    # - a JobService URL has not been provided, i.e. EC runs without needs to contact JS
    # - we already have a Job URL, i.e. the job entry has already been created
    def create_job
      return unless @job_url.nil?
      return if @js_url.nil?
      require 'json'
      require 'net/http'
      begin
        job = { name: self.id }
        u = URI.parse(@js_url+'/jobs')
        req = Net::HTTP::Post.new(u.path, {'Content-Type' =>'application/json'})
        req.body = JSON.pretty_generate(job)
        res = Net::HTTP.new(u.host, u.port).start {|http| http.request(req) }
        raise "Could not create a job for this experiment trial\n"+
              "Response #{res.code} #{res.message}:\n#{res.body}" unless res.kind_of? Net::HTTPSuccess
        job = JSON.parse(res.body)
        raise "No valid URL received for the created job for this experiment trial" if job['href'].nil?
        @job_url = job['href']
      end
    end

    # Purely for backward compatibility
    class << self
      # Disconnect communicator, try to delete any XMPP affiliations
      def done
        info "Experiment: #{OmfEc.experiment.id} finished"
        info "Release applications and network interfaces"
        info "Exit in 15 seconds..."

        # Make sure that all defined events are removed
        OmfEc.experiment.clear_events

        OmfCommon.el.after(10) do
          allGroups do |g|
            g.resources[type: 'application'].release unless g.app_contexts.empty?
            g.resources[type: 'net'].release unless g.net_ifs.find_all { |v| v.conf[:type] == 'net' }.empty?
            g.resources[type: 'wlan'].release unless g.net_ifs.find_all { |v| v.conf[:type] == 'wlan' }.empty?
            g.resources.membership = { leave: g.address }
          end

          OmfCommon.el.after(4) do
            info "OMF Experiment Controller #{OmfEc::VERSION} - Exit."
            OmfCommon.el.after(1) do
              OmfCommon.comm.disconnect
              OmfCommon.eventloop.stop
            end
          end
        end
        OmfEc.experiment.log_metadata("state", "finished")
      end

      def disconnect
        info "Disconnecting in 5 sec from experiment: #{OmfEc.experiment.id}"
        info "Run the EC again to reattach"
        OmfCommon.el.after(5) do
          OmfCommon.comm.disconnect
          OmfCommon.eventloop.stop
        end
      end

      def start
        info "Experiment: #{OmfEc.experiment.id} starts"
        info "Slice: #{OmfEc.experiment.sliceID}" unless OmfEc.experiment.sliceID.nil?
        OmfEc.experiment.log_metadata("state", "running")

        allGroups do |g|
          info "CONFIGURE #{g.members.size} resources to join group #{g.name}"
          debug "CONFIGURE #{g.members.keys} to join group #{g.name}"
          g.members.each do |key, value|
            OmfEc.subscribe_and_monitor(key) do |res|
              #info "Configure '#{key}' to join '#{g.name}'"
              g.synchronize do
                g.members[key] = res.address
              end
              res.configure({ membership: g.address, res_index: OmfEc.experiment.nodes.index(key) }, { assert: OmfEc.experiment.assertion })
            end
          end
        end

        # For every 100 nodes, increase check interval by 1 second
        count = allGroups.inject(0) { |c, g| c += g.members.size }
        interval = count / 100
        interval = 1 if interval < 1
        info "TOTAL resources: #{count}. Events check interval: #{interval}."

        OmfCommon.el.every(interval) do
          EM.next_tick do
            OmfEc.experiment.process_events rescue nil
          end
        end
      end

      # Ask the resources which joined the groups I created to leave
      #
      def leave_memberships
        all_groups do |g|
          g.resources.membership = { leave: g.address }
        end
      end
    end
  end
end
