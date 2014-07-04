# Copyright (c) 2014 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License

require 'hashie'

module OmfEc
  class Runner
    include Hashie

    attr_reader :oedl_path

    def initialize
      @gem_version = OmfEc::VERSION
      @oml_enabled = false
      @executable_name = File.basename($PROGRAM_NAME)

      @oml_opts = {
        appName: @executable_name,
        afterParse: lambda { |o| parse_cmd_opts }
      }

      # Default configuration options
      @config_opts = Mash.new(
        environment: 'development',
        communication: { url: "amqp://localhost" },
        logging: {
          level: { default: 'debug' },
          appenders: {
            stdout: {
              level: :info,
              date_pattern: '%H:%M:%S',
              pattern: '%d %5l %c{2}: %m\n'
            },
            rolling_file: {
              level: :debug,
              log_dir: '/var/tmp',
              size: 1024*1024*50, # max 50mb of each log file
              keep: 5, # keep a 5 logs in total
              date_pattern: '%F %T %z',
              pattern: '[%d] %-5l %c: %m\n'
            }
          }
        }
      )

      @cmd_opts = Mash.new

      @argv = ARGV.dup
    end

    def oml_init
      begin
        @oml_enabled = OML4R::init(ARGV, @oml_opts) do |op|
          op.banner = "OMF Experiment Controller version '#{@gem_version}'\n"
          op.banner += "Usage: #{@executable_name} [options] path_to_oedl_file [-- --experiment_property value]"

          op.on("-u", "--uri ADDRESS", "URI for communication layer [amqp://localhost]") do |uri|
            @cmd_opts[:uri] = uri
            remove_cmd_opts_from_argv("-u", "--uri", uri)
          end

          op.on("-c CONFIGFILE", "Configuration File") do |file|
            @cmd_opts[:config_file] = file
            remove_cmd_opts_from_argv("-c", file)
          end

          op.on("--log_config CONFIGFILE", "Logging Configuration File") do |file|
            @cmd_opts[:logging_configfile] = file
            remove_cmd_opts_from_argv("--log_config", file)
          end

          op.on("-e ENVIRONMENT", "Environment (development, production ...) [#{@config_opts[:environment]}]") do |e|
            @cmd_opts[:environment] = e
            remove_cmd_opts_from_argv("-e", e)
          end

          op.on("--root_cert_dir DIRECTORY", "Directory containing root certificates") do |dir|
            @cmd_opts[:root_cert_dir] = dir
            remove_cmd_opts_from_argv("--root_cert_dir", dir)
          end

          op.on("--cert CERTIFICATE", "Your certificate") do |cert|
            @cmd_opts[:cert] = cert
            remove_cmd_opts_from_argv("--cert", cert)
          end

          op.on("--key KEY", "Your private key") do |key|
            @cmd_opts[:key] = key
            remove_cmd_opts_from_argv("--key", key)
          end

          op.on("--name", "--experiment EXPERIMENT_NAME", "Experiment name") do |e_name|
            @cmd_opts[:experiment_name] = e_name
            OmfEc.experiment.name = e_name
            remove_cmd_opts_from_argv("--name", "--experiment", e_name)
          end

          op.on("--slice SLICE_NAME", "Slice name [Deprecated]") do |slice|
            @cmd_opts[:slice] = slice
            remove_cmd_opts_from_argv("--slice", slice)
          end

          op.on("--oml_uri URI", "URI for the OML data collection of experiment applications") do |uri|
            @cmd_opts[:oml_uri] = uri
            remove_cmd_opts_from_argv("--oml_uri", uri)
          end

          op.on("--inst_oml_uri URI", "EC Instrumentation: OML URI to use") do |uri|
            @cmd_opts[:inst_oml_uri] = uri
            remove_cmd_opts_from_argv("--inst_oml_uri", uri)
          end

          op.on("--inst_oml_id ID", "EC Instrumentation: OML ID to use") do |id|
            @cmd_opts[:inst_oml_id] = id
            remove_cmd_opts_from_argv("--inst_oml_id", id)
          end

          op.on("--inst_oml_domain DOMAIN", "EC Instrumentation: OML Domain to use") do |domain|
            @cmd_opts[:inst_oml_domain] = domain
            remove_cmd_opts_from_argv("--inst_oml_domain", domain)
          end

          op.on("-g", "--show-graph", "Parse graph definition to construct graph information in log output") do
            @cmd_opts['show-graph'] = true
            remove_cmd_opts_from_argv("--show-graph")
          end

          op.on("-v", "--version", "Show version") do
            puts "OMF Experiment Controller version '#{@gem_version}'"
            exit
          end

          op.on("-d", "--debug", "Debug mode (Set logging level in Stdout to :debug)") do
            @cmd_opts[:debug] = true
            remove_cmd_opts_from_argv("-d", "--debug")
          end

          op.on("-h", "--help", "Show this message") do
            puts op
            exit
          end
        end
      rescue OML4R::MissingArgumentException => e
        puts "Warning: #{e.message} to instrument, so it will run without instrumentation. (see --oml-help)"
      rescue => e
        puts e.message
        puts e.backtrace.join("\n")
        exit(1)
      end
    end

    def parse_cmd_opts
      parse_config_file

      # uri in command line is short for communication/url
      uri = @cmd_opts.delete(:uri)
      @config_opts[:communication][:url] = uri if uri
      @config_opts[:communication][:auth] = { authenticate: true } if @cmd_opts[:cert]


      @config_opts.merge!(@cmd_opts)

      if @config_opts[:oml_uri]
        # Only change default if they are not set in config file
        @config_opts[:logging][:appenders][:oml4r] ||= {
          level: :info,
          appName: 'omf_ec',
          domain: OmfEc.experiment.id,
          collect: @config_opts[:oml_uri]
        }
      end
    end

    def parse_config_file
      if (config_file = @cmd_opts.delete(:config_file))
        if File.exist?(config_file)
          @config_opts.merge!(OmfCommon.load_yaml(config_file, erb_process: true))
        else
          puts "Config file '#{config_file}' doesn't exist"
          exit(1)
        end
      end
    end

    def remove_cmd_opts_from_argv(*args)
      args.each { |v| @argv.slice!(@argv.index(v)) if @argv.index(v) }
    end

    def setup_experiment
      OmfEc.experiment.oml_uri = @config_opts[:oml_uri] if @config_opts[:oml_uri]
      OmfEc.experiment.show_graph = @config_opts['show-graph']

      # Instrument EC
      if @config_opts[:inst_oml_uri] && @config_opts[:inst_oml_id] && @config_opts[:inst_oml_domain]
        instrument_ec = OML4R::init(nil, {
          collect: @config_opts[:inst_oml_uri],
          nodeID: @config_opts[:inst_oml_id],
          domain: @config_opts[:inst_oml_domain],
          appName: @executable_name
        })

        OmfCommon::Measure.enable if instrument_ec
      end

      remove_cmd_opts_from_argv("exec")

      index_of_dividing_hyphen = @argv.index("--")

      @argv[0..index_of_dividing_hyphen || -1].in_groups_of(2) do |arg_g|
        if arg_g[0] =~ /^--(.+)/ && !arg_g[1].nil?
          remove_cmd_opts_from_argv(*arg_g)
        end
      end

      @oedl_path = @argv[0] && File.expand_path(@argv[0])

      if @oedl_path.nil? || !File.exist?(@oedl_path)
        puts "Experiment script '#{@argv[0]}' not found"
        exit(1)
      end

      @argv.slice!(0)

      # User-provided command line values for Experiment Properties cannot be
      # set here as the properties have not been defined yet by the experiment.
      # Thus just pass them to the experiment, which will be responsible
      # for setting them later
      properties = {}
      if index_of_dividing_hyphen
        remove_cmd_opts_from_argv("--")
        exp_properties = @argv
        exp_properties.in_groups_of(2) do |p|
          unless p[0] =~ /^--(.+)/ && !p[1].nil?
            puts "Malformatted properties '#{exp_properties.join(' ')}'"
            exit(1)
          else
            properties[$1.to_sym] = p[1].ducktype
            remove_cmd_opts_from_argv(*p)
          end
        end
        OmfEc.experiment.cmdline_properties = properties
      end
    end

    def setup_logging
      OmfCommon.load_logging_config(@config_opts[:logging_configfile])

      if @config_opts[:debug]
        Logging.logger.root.level = 'debug'
        stdout_appender = Logging.logger.root.appenders.find { |a| a.class == Logging::Appenders::Stdout }
        stdout_appender.level = 'debug' if stdout_appender
      else
        Logging.consolidate 'OmfCommon', 'OmfRc'
      end
    end

    def load_experiment
      begin
        OmfCommon.init(@config_opts.delete(:environment), @config_opts) do |el|
          setup_logging
          OmfCommon.comm.on_connected do |comm|
            info "OMF Experiment Controller #{OmfEc::VERSION} - Start"
            info "Connected using #{comm.conn_info}"
            info "Execute: #{@oedl_path}"
            info "Properties: #{OmfEc.experiment.cmdline_properties}"

            if @config_opts[:communication][:auth] && @config_opts[:communication][:auth][:authenticate]
              ec_cert = OmfCommon.load_credentials(
                root_cert_dir: @config_opts[:root_cert_dir],
                entity_cert: @config_opts[:cert],
                entity_key: @config_opts[:key]
              )

              ec_cert.resource_id = OmfCommon.comm.local_address
              OmfCommon::Auth::CertificateStore.instance.register(ec_cert)
            end

            OmfEc.experiment.log_metadata("ec_version", "#{OmfEc::VERSION}")
            OmfEc.experiment.log_metadata("exp_path", @oedl_path)
            OmfEc.experiment.log_metadata("ec_pid", "#{Process.pid}")
            OmfEc.experiment.archive_oedl(@oedl_path)

            begin
              load @oedl_path
              OmfEc::Experiment.start
            rescue => e
              OmfEc.experiment.log_metadata("state", "error")
              error e.message
              error e.backtrace.join("\n")
            end

            trap(:TERM) { OmfEc::Experiment.done }
            trap(:INT) { OmfEc::Experiment.done }
          end
        end
      rescue => e
        logger.fatal e.message
        logger.fatal e.backtrace.join("\n")
        puts "Experiment controller exits unexpectedly"
        puts e
        exit(1)
      end
    end

    def init
      oml_init
      setup_experiment
    end

    def run
      load_experiment
    end
  end
end
