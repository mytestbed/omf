# Copyright (c) 2013 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfRc
  # Class to start an OMF RC. The configuration parameters can be set
  # in decreasing priority through the command line,  configuration
  # file and default settings (see @def_opts).
  #
  # For historic reasons and to make this implementation more interesting
  # there are two different config file formats. A 'normal' one inherited from
  # earlier version of OMF, and an 'advanced' one which is identical to the
  # format accepted by OmfCommon.init(). To maintain some level of sanity,
  # only one configuration file is accepted.
  #
  # Having said that, there is one exception and that relates to the 'oml'
  # configuration which is stripped out first and handed to the OML4R library
  # during command line parsing.
  #
  class Runner
    include Hashie

    attr_accessor :gopts, :copts, :def_opts
    attr_accessor :opts

    def initialize()
      @executable_name = File.basename($PROGRAM_NAME)
      @oml_enabled = false
      @gem_version = OmfCommon.version_of('omf_common')

      @node_id = Socket.gethostname

      @def_opts = Mash.new(
        environment: 'production',
        resources: [ { type: :node, uid: @node_id }],
        factories: [],
        communication: { url: "xmpp://#{@node_id}-#{Process.pid}:#{@node_id}-#{Process.pid}@localhost" },
        add_default_factories: true,
      )

      @gopts = Mash.new(
        config_file: nil,
        adv_config_file: nil,
        logging_configfile: nil,
        environment: nil
      )

      @opts = Mash.new

      @omlopts = {appName: @executable_name}
    end

    def run()
      oml_init() # calls parse_config_files()

      OmfCommon::Measure.enable if @oml_enabled

      OmfCommon.init(@opts[:environment], @opts.to_hash) do |el|
        # Load a customised logging set up if provided
        OmfCommon.load_logging_config(@opts[:logging_configfile])

        info "Starting OMF Resource Controller version '#{@gem_version}'"

        Signal.trap("SIGINT") do
          # TODO: Should release resources first
          info "Stopping ..."
          OmfCommon.comm.disconnect
          OmfCommon.eventloop.stop
        end

        # Load extensions
        if @opts[:add_default_factories] != false
          OmfRc::ResourceFactory.load_default_resource_proxies
        end

        @opts[:factories].each do |f|
          if (req = f[:require])
            begin
              info "Try to load resource module '#{req}'"
              require(req)
            rescue LoadError => e
              error e.message
            end
          end
        end

        OmfCommon.comm.on_connected do |comm|
          info "Connected using #{comm.conn_info}"

          rc_cert = OmfCommon.load_credentials(@opts[:credentials])

          @opts[:resources].each do |res_opts|
            rtype = res_opts.delete(:type)
            res_creation_opts = res_opts.delete(:creation_opts)
            res_creation_opts ||= res_opts.delete(:create_opts)
            res_creation_opts ||= {}
            res_opts[:certificate] = rc_cert
            begin
              OmfRc::ResourceFactory.create(rtype, res_opts, res_creation_opts)
            rescue => e
              error "#{e.message}\n#{e.backtrace.join("\n")}"
            end
          end

        end
      end
      info "Stopping OMF Resource Controller version '#{@gem_version}'"
    end

    def parse_config_files()
      config_file = @gopts[:config_file]

      if config_file.nil?
        puts "You must specify a config file"
        exit(1)
      else
        cfg_opts = Mash.new(OmfCommon.load_yaml(config_file, symbolize_keys: true, erb_process: true))

        @opts.merge!(@def_opts.merge(cfg_opts))

        # Legacy support uri & uid opt could also configure comm & resource
        cfg_opts.each do |k, v|
          case k.to_sym
          when :uri
            @opts[:communication][:url] = v
          when :uid
            @opts[:resources][0][:type] = :node
            @opts[:resources][0][:uid] = v
          else
            @opts[k] = v
          end
        end

        @omlopts.merge(@opts[:instrumentation] || {}) { |k, v1, v2| v1 } # merge in place as OML may hold @omlopts
      end
    end

    def oml_init
      begin
        @omlopts[:afterParse] = lambda {|o| parse_config_files() }
        @oml_enabled = OML4R::init(ARGV, @omlopts) do |op|
          op.banner = "OMF Resource Controller version '#{@gem_version}'\n"
          op.banner += "Usage: #{@executable_name} [options]"

          op.on("-c CONFIGFILE", "Configuration File") do |file|
            @gopts[:config_file] = file
          end

          op.on("-a ADVANCED_CONFIGFILE", "Advanced Configuration File") do |file|
            @gopts[:adv_config_file] = file
          end

          op.on("--log_config CONFIGFILE", "Logging Configuration File") do |file|
            @gopts[:logging_configfile] = file
          end

          op.on("-e ENVIRONMENT", "Environment (development, production ...) [#{@def_opts[:environment]}]") do |e|
            @gopts[:environment] = e
          end

          op.on("-v", "--version", "Show version") do
            puts "OMF Resource Controller version '#{@gem_version}'"
            exit
          end

          op.on("-h", "--help", "Show this message") do
            puts op
            exit
          end
        end
      rescue OML4R::MissingArgumentException => e
        puts "Warning: #{e.message} to instrument this RC, so it will run without instrumentation. (see --oml-help)"
      rescue => e
        puts e.message
        #puts e.backtrace
        exit(1)
      end
    end
  end
end
