# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

# This module defines a Resource Proxy (RP) for an Application.
# For a detailed usage tutorial see {file:doc/DEVELOPERS.mkd Resource Proxy tutorial}
#
# Utility dependencies: platform_toos, common_tools
#
# This Application Proxy has the following properties:
#
# - binary_path (String) the path to the binary of this app
# - pkg_tarball (String) the URI of the installation tarball of this app
# - pkg_ubuntu (String) the name of the Ubuntu package for this app
# - pkg_fedora (String) the name of the Fedora package for this app
# - state (String) the state of this Application RP
#   (stopped, running, paused, installed)
# - installed (Boolean) is this application installed? (default false)
# - force_tarball_install (Boolean) if true then force the installation
#   from tarball even if other distribution-specific installation are
#   available (default false)
# - map_err_to_out (Boolean) if true then map StdErr to StdOut for this
#   app (default false)
# - platform (Symbol) the OS platform where this app is running
# - environment (Hash) the environment variables to set prior to starting
#   this app. { k1 => v1, ... } will result in "env -i K1=v1 ... "
#   (with k1 being either a String or a Symbol)
# - clean_env (Boolean) if true, application will be executed in a clean environment (env -i). Default is TRUE.
# - use_oml (Boolean) if true enable OML for this application (default false)
# - oml_loglevel (Integer) set a specific OML log level (default unset)
# - oml_logfile (String) set a specific path for OML log file (default unset)
# - oml_configfile (String) path of the OML config file (optional)
# - oml (Hash) OML specific properties (optional), this Hash contains the
#   following keys:
#       - :available_mps (Array) list of available OML Measurement Points (Hash)
#       - :collection (Hash) list of required OML Measurement Stream to collect
#           when this application is running (defined in liboml2.conf manpage)
#           http://omf.mytestbed.net/doc/oml/html/liboml2.conf.html
#       - :experiment (String) name of the experiment in which this application
#           is running
#       - :id (String) OML id to use for this application when it is running
# - parameters (Hash) the command line parameters available for this app.
#   This hash is of the form: { :param1 => attribut1, ... }
#   with param1 being the id of this parameter for this Proxy and
#   with attribut1 being another Hash with the following possible
#   keys and values (all are optional):
#     :cmd (String) the command line for this parameter
#     :order (Fixnum) the appearance order on the command line, default FIFO
#     :dynamic (Boolean) parameter can be dynammically changed, default false
#     :type (Numeric|String|Boolean) this parameter's type
#     :default value given by default to this parameter
#     :value value to set for this parameter
#     :mandatory (Boolean) this parameter is mandatory, default false
#
# Note: this application proxy will merge new Hash values for the properties
# environment, oml, and parameters properties with the old Hash values.
#
# Two examples of valid parameters definition are:
#
#     { :host => {:default => 'localhost', :type => 'String',
#             :mandatory => true, :order => 2},
#       :port => {:default => 5000, :type => 'Numeric', :cmd => '-p',
#             :mandatory => true, :order => 1},
#       :size => {:default => 512, :type => 'Numeric', :cmd => '--pkt-size',
#             :mandatory => true, :dynamic => true}
#       :title => {:type => 'String', :mandatory => false}
#     }
#
# and
#
#     { :title => {:value => "My First Application"} }
#
module OmfRc::ResourceProxy::Application
  include OmfRc::ResourceProxyDSL
  # @!macro extend_dsl

  require 'omf_common/exec_app'

  register_proxy :application
  # @!parse include OmfRc::Util::PlatformTools
  # @!parse include OmfRc::Util::CommonTools
  utility :platform_tools
  utility :common_tools

  MAX_PARAMETER_NUMBER = 1000
  DEFAULT_MANDATORY_PARAMETER = false

  property :app_id, :default => nil
  property :description, :default => ''
  property :binary_path, :default => nil
  property :quiet, :default => false
  property :platform, :default => nil
  property :pkg_tarball, :default => nil
  property :tarball_install_path, :default => '/'
  property :force_tarball_install, :default => false
  property :pkg_ubuntu, :default => nil
  property :pkg_fedora, :default => nil
  property :state, :default => :stopped
  property :installed, :default => false
  property :map_err_to_out, :default => false
  property :event_sequence, :default => 0
  property :parameters, :default => Hashie::Mash.new
  property :environments, :default => Hashie::Mash.new
  property :clean_env, :default => true
  property :use_oml, :default => false
  property :oml_configfile, :default => nil
  property :oml, :default => Hashie::Mash.new
  property :oml_logfile, :default => nil
  property :oml_loglevel, :default => nil

  # @!macro group_hook
  #
  # hook :before_ready do |res|
    # define_method("on_app_event") { |*args| process_event(self, *args) }
  # end

  hook :before_release do |app|
    app.configure_state(:stopped)
  end

  # @!macro hook
  # @!method after_initial_configured
  hook :after_initial_configured do |res|
    # if state was set to running or installing from the create we need
    # to make sure that this happens!
    if res.property.state.to_s.downcase.to_sym == :running
      res.property.state = :stopped
      res.switch_to_running
    elsif res.property.state.to_s.downcase.to_sym == :installing
      res.property.state = :stopped
      res.switch_to_installing
    end
  end

  # @!endgroup

  # This method processes an event coming from the application instance, which
  # was started by this Resource Proxy (RP). It is a callback, which is usually
  # called by the ExecApp class in OMF
  #
  # @param [AbstractResource] res this RP
  # @param [String] event_type the type of event from the app instance
  #                 (STARTED, EXIT, STDOUT, STDERR)
  # @param [String] app_id the id of the app instance
  # @param [String] msg the message carried by the event
  def process_event(res, event_type, app_id, msg)
      logger.info "App Event from '#{app_id}' "+
                  "(##{res.property.event_sequence}) - "+
                  "#{event_type}: '#{msg}'"
      res.property.event_sequence += 1
      res.property.installed = true if app_id.include?("_INSTALL") &&
                                       event_type.to_s.include?('EXIT') &&
                                       msg == "0"
      if event_type == 'EXIT'
        res.property.state = :stopped
        res.inform(:status, {
                        status_type: 'APP_EVENT',
                        event: event_type.to_s.upcase,
                        app: app_id,
                        exit_code: msg,
                        msg: msg,
                        state: res.property.state,
                        seq: res.property.event_sequence,
                        uid: res.uid # do we really need this? Should be identical to 'src'
                      }, :ALL)
      else
        res.inform(:status, {
                      status_type: 'APP_EVENT',
                      event: event_type.to_s.upcase,
                      app: app_id,
                      msg: msg,
                      seq: res.property.event_sequence,
                      uid: res.uid
                    }, :ALL) unless res.property.quiet
      end
  end

  # @!macro group_request
  #
  # Request the platform property of this Application RP
  # @see OmfRc::ResourceProxy::Application
  #
  # @!macro request
  # @!method request_platform
  request :platform do |res|
    res.property.platform = detect_platform if res.property.platform.nil?
    res.property.platform.to_s
  end

  # @!endgroup
  # @!macro group_configure

  # Configure the environments and oml property of this Application RP
  # @see OmfRc::ResourceProxy::Application
  #
  #
  # @!macro configure
  # @!method conifgure_environments
  # @!method conifgure_oml
  %w(environments oml).each do |prop|
    configure(prop) do |res, value|
      if value.kind_of? Hash
        res.property[prop] = res.property[prop].merge(value)
      else
        res.log_inform_error "Configuration failed for '#{prop}'! "+
          "Value not passed as Hash (#{value.inspect})"
      end
      res.property[prop]
    end
  end

  # Configure the parameters property of this Application RP
  #
  # @!macro configure
  # @see OmfRc::ResourceProxy::Application
  # @!method configure_parameters
  #
  configure :parameters do |res, params|
    if params.kind_of? Hash
      params.each do |p,v|
        if v.kind_of? Hash
          # if this param has no set order, then assign the highest number to it
          # this will allow sorting the parameters later
          v[:order] = MAX_PARAMETER_NUMBER if v[:order].nil?
          # if this param has no set mandatory field, assign it a default one
          v[:mandatory] = DEFAULT_MANDATORY_PARAMETER if v[:mandatory].nil?
          new_val = res.property.parameters[p].nil? ? v : res.property.parameters[p].merge(v)
          # only set this new parameter if it passes the type check
          if res.pass_type_checking?(new_val)
            res.property.parameters[p] = new_val
            res.dynamic_parameter_update(p,new_val)
          else
            res.log_inform_error "Configuration of parameter '#{p}' failed "+
              "type checking. Defined type is #{new_val[:type]} while assigned "+
              "value/default are #{new_val[:value].inspect} / "+
              "#{new_val[:default].inspect}"
          end
        else
          res.log_inform_error "Configuration of parameter '#{p}' failed!"+
            "Options not passed as Hash (#{v.inspect})"
        end
      end
    else
      res.log_inform_error "Parameter configuration failed! Parameters not "+
        "passed as Hash (#{params.inspect})"
    end
    res.property.parameters
  end

  # Configure the state of this Application RP. The valid states are
  # stopped, running, paused, installing. The semantic of each states are:
  #
  # - stopped: the initial state for an Application RP
  # - running: upon entering in this state, a new instance of the application is
  #   started, the Application RP stays in this state until the
  #   application instance is finished or paused. The Application RP can
  #   only enter this state from a previous paused or stopped state.
  # - paused: upon entering this state, the currently running instance of this
  #   application should be paused (it is the responsibility of
  #   specialised Application Proxy to ensure that! This default
  #   Application Proxy does nothing to the application instance when
  #   entering this state). The Application RP can only enter this
  #   state from a previous running state.
  # - installing: upon entering in this state, a new installation of the
  #   application will be performed by the Application RP, which will
  #   stay in this state until the installation is done. The
  #   Application RP can only enter this state from a previous stopped
  #   state. Furthermore it can only exit this state to enter the stopped state
  #   only when the installatio is done. Supported install methods are: Tarball,
  #   Ubuntu, and Fedora
  #
  # @param [String] value the state to set this app into
  # @!macro configure
  # @!method configure_state
  configure :state do |res, value|
    OmfCommon.eventloop.after(0) do
      case value.to_s.downcase.to_sym
      when :installing then res.switch_to_installing
      when :stopped then res.switch_to_stopped
      when :running then res.switch_to_running
      when :paused then res.switch_to_paused
      else
        res.log_inform_warn "Cannot switch application to unknown state '#{value.to_s}'!"
      end
    end
    res.property.state
  end

  # @!endgroup

  # @!macro group_work
  #
  # Swich this Application RP into the 'installing' state
  # (see the description of configure :state)
  # @!macro work
  # @!method switch_to_installing
  work('switch_to_installing') do |res|
    if res.property.state.to_sym == :stopped
      if res.property.installed
        res.log_inform_warn "The application is already installed"
      else
        # Select the proper installation method based on the platform
        # and the value of 'force_tarball_install'
        res.property.state = :installing
        if res.property.force_tarball_install ||
          (res.property.platform == :unknown)
          installing = res.install_tarball(res.property.pkg_tarball,
              res.property.tarball_install_path)
        elsif res.property.platform == :ubuntu
          installing = res.install_ubuntu(res.property.pkg_ubuntu)
        elsif res.property.platform == :fedora
          installing = res.install_fedora(res.property.pkg_fedora)
        end
        res.property.state = :stopped unless installing
      end
    else
      # cannot install as we are not stopped
      res.log_inform_warn "Not in stopped state. Cannot switch to installing state!"
    end
  end

  # Switch this Application RP into the 'stopped' state
  # (see the description of configure :state)
  #
  # @!macro work
  # @!method switch_to_stopped
  work('switch_to_stopped') do |res|
    if res.property.state == :running || res.property.state == :paused
      id = res.property.app_id
      unless ExecApp[id].nil?
        # stop this app
        begin
          # first, try sending 'exit' on the stdin of the app, and wait
          # for 4s to see if the app acted on it...
          ExecApp[id].stdin('exit')
          sleep 4
          unless ExecApp[id].nil?
            # second, try sending TERM signal, wait another 4s to see
            # if the app acted on it...
            ExecApp[id].signal('TERM')
            sleep 4
            # finally, try sending KILL signal
            ExecApp[id].signal('KILL') unless ExecApp[id].nil?
          end
          res.property.state = :stopped
        rescue => err
        end
      end
    end
  end

  # Switch this Application RP into the 'running' state
  # (see the description of configure :state)
  #
  # @!macro work
  # @!method switch_to_running
  work('switch_to_running') do |res|
    if res.property.state == :stopped
      # start a new instance of this app
      res.property.app_id = res.hrn.nil? ? res.uid : res.hrn
      # we need at least a defined binary path to run an app...
      if res.property.binary_path.nil?
        res.log_inform_warn "Binary path not set! No Application to run!"
      else
        ExecApp.new(res.property.app_id,
                    res.build_command_line,
                    res.property.map_err_to_out) do |event_type, app_id, msg|
                      res.process_event(res, event_type, app_id, msg)
                    end
        res.property.state = :running
      end
    elsif res.property.state == :paused
      # resume this paused app
      res.property.state = :running
      # do more things here...
    else
      # cannot run as we are still installing
      res.log_inform_warn "Cannot switch to running state as current state is '#{res.property.state}'"
    end
  end

  # Swich this Application RP into the 'paused' state
  # (see the description of configure :state)
  #
  # @!macro work
  # @!method switch_to_paused
  work('switch_to_paused') do |res|
    if res.property.state == :running
      # pause this app
      res.property.state = :paused
      # do more things here...
    end
  end

  # Check if a parameter is dynamic, and if so update its value if the
  # application is currently running
  #
  # @yieldparam [String] name the parameter id as known by this app
  # @yieldparam [Hash] att the Hash holding the parameter's attributs
  # @see OmfRc::ResourceProxy::Application
  #
  # @!macro work
  # @!method dynamic_parameter_update
  work('dynamic_parameter_update') do |res,name,att|
    # Only update a parameter if it is dynamic and the application is running
    dynamic = false
    dynamic = att[:dynamic] if res.boolean?(att[:dynamic])
    if dynamic && res.property.state == :running
      line = ""
      line += "#{att[:cmd]} " unless att[:cmd].nil?
      line += "#{att[:value]}"
      ExecApp[res.property.app_id].stdin(line)
      logger.info "Updated parameter '#{name}' with value '#{att[:value].inspect}' (stdin: '#{line}')"
    end
  end

  # Check if a configured value or default for a parameter has the same
  # type as the type defined for that parameter
  # The checking procedure is as follows:
  # - first check if a type was set for this parameter, if not then return true
  #   (thus if no type was defined for this parameter then return true
  #   regardless of the type of the given value or default)
  # - second check if a value is given, if so check if it has the same type as
  #   the defined type, if so then return true, if not then return false.
  # - third if no value is given but a default is given, then perform the same
  #   check as above but using the default in-place of the value
  #
  # @param [Hash] att the Hash holding the parameter's attributs
  #
  # @return [Boolean] true or false
  # @!macro work
  work('pass_type_checking?') do |res,att|
    passed = false
    unless att[:type].nil?
      if att[:type] == 'Boolean' # HACK: as Ruby does not have a Boolean type
        if !att[:default].nil? && !att[:value].nil?
          passed = true if res.boolean?(att[:default]) && res.boolean?(att[:value])
        elsif att[:default].nil? && att[:value].nil?
          passed = true
        elsif att[:default].nil?
          passed = true if res.boolean?(att[:value])
        elsif att[:value].nil?
          passed = true if res.boolean?(att[:default])
        end
      else # Now for all other types...
        klass = Module.const_get(att[:type].capitalize.to_sym)
        if !att[:default].nil? && !att[:value].nil?
          passed = true if att[:default].kind_of?(klass) && att[:value].kind_of?(klass)
        elsif att[:default].nil? && att[:value].nil?
          passed = true
        elsif att[:default].nil?
          passed = true if att[:value].kind_of?(klass)
        elsif att[:value].nil?
          passed = true if att[:default].kind_of?(klass)
        end
      end
    else
      passed = true
    end
    passed
  end

  # Build the command line, which will be used to start this app.
  #
  # This command line will be of the form:
  # "env -i VAR1=value1 ... application_path parameterA valueA ..."
  #
  # The environment variables and the parameters in that command line are
  # taken respectively from the 'environments' and 'parameters' properties of
  # this Application Resource Proxy. If the 'use_oml' property is set, then
  # add to the command line the necessary oml parameters.
  #
  # @return [String] the full command line
  # @!macro work
  work('build_command_line') do |res|
    if res.property.clean_env
      cmd_line = "env -i " # Start with a 'clean' environment
      if env = res.defaults(:env)
        env = env.map {|k,v| "#{k.to_s.upcase}=#{v}"}.join(' ')
        cmd_line += "#{env} "
      end
    else
      cmd_line = ""
    end

    res.property.environments.each do |e,v|
      val = v.kind_of?(String) ? "'#{v}'" : v
      cmd_line += "#{e.to_s.upcase}=#{val} "
    end
    cmd_line += res.property.binary_path + " "
    # Add command line parameter in their specified order if any
    sorted_parameters = res.property.parameters.sort_by {|k,v| v[:order] || -1}
    sorted_parameters.each do |param,att|
      needed = false
      needed = att[:mandatory] if res.boolean?(att[:mandatory])
      # For mandatory parameter without a value, take the default one
      val = (needed && att[:value].nil?) ? att[:default] : att[:value]
      # Finally add the parameter if is value/default is not nil
      unless val.nil?
        if att[:type] == "Boolean"
          # for Boolean param, only the command is printed if value==true
          cmd_line += "#{att[:cmd]} " if val == true
        else
          # for all other type of param, we print "cmd value"
          # with a user-provided prefix/suffix if defined
          cmd_line += "#{att[:cmd]} "
          cmd_line += att[:prefix].nil? ? "#{val}" : "#{att[:prefix]}#{val}"
          cmd_line += att[:suffix].nil? ? " " : "#{att[:suffix]} "
        end
      end
    end
    # Add OML parameters if required
    cmd_line = res.build_oml_config(cmd_line) if res.property.use_oml
    cmd_line
  end

  # Add the required OML parameter to the command line for this application
  #
  # - if the 'oml_configfile' property is set with a filename, then we use that
  #   file as the OML Configuration file. Thus we add the parameter
  #   "--oml-config filename" to this application's command line
  # - if the 'oml' property is set with a Hash holding an OML configuration,
  #   then we write turn it into OML's XML configuration representation, write
  #   it to a temporary file, and add the parameter "--oml-config tmpfile" to
  #   this application's command line. The OML configuration hash is based
  #   on the liboml2.conf man page, an example of which is:
  #       <omlc domain="my_experiment" id="my_source_id">
  #         <collect url="tcp://10.0.0.200">
  #           <stream mp="radiotap" interval="2">
  #             <filter field="sig_strength_dBm" />
  #             <filter field="noise_strength_dBm" />
  #             <filter field="power" />
  #           </stream>
  #           <stream mp="udp" samples="10">
  #             <filter field="udp_len" />
  #           </stream>
  #         </collect>
  #       </omlc>
  #
  # The 'oml_configfile' case takes precedence over the 'oml' case above.
  #
  # Regardless of which case is performed, we will always set the
  # '--oml-log-level' and '--oml-log-file' parameter on the command line if
  # the corresponsding 'oml_logfile' and 'oml_loglevel' properties are set for
  # this application resource.
  #
  # @param [String] cmd the String to which OML parameters will be added
  #
  # @return [String] the resulting command line
  # @!macro work
  work('build_oml_config') do |res, cmd|
    if !res.property.oml_configfile.nil?
      if File.exist?(res.property.oml_configfile)
        cmd += "--oml-config #{res.property.oml_configfile} "
      else
        res.log_inform_warn "OML enabled but OML config file does not exist"+
        "(file: '#{res.property.oml_configfile}')"
      end
    elsif !res.property.oml.collection.nil?
      o = res.property.oml
      ofile = "/tmp/#{res.uid}-#{Time.now.to_i}.xml"
      of = File.open(ofile,'w')
      of << "<omlc experiment='#{o.experiment}' id='#{res.opts.parent.uid}_#{o.id}_#{res.uid}'>\n"
      o.collection.each do |c|
        of << "  <collect url='#{c.url}'>\n"
        c.streams.each do |m|
          # samples as precedence over interval
          s = ''
          s = "interval='#{m.interval}'" if m.interval
          s = "samples='#{m.samples}'" if m.samples
          of << "    <stream mp='#{m.mp}' #{s}>\n"
          unless m.filters.nil?
            m.filters.each do |f|
              line = "      <filter field='#{f.field}' "
              line += "operation='#{f.operation}' " unless f.operation.nil?
              line += "rename='#{f.rename}' " unless f.rename.nil?
              line += "/>\n"
              of << line
            end
          end
          of << "    </stream>\n"
        end
        of << "  </collect>\n"
      end
      of << "</omlc>\n"
      of.close
      cmd += "--oml-config #{ofile}"
    else
      res.log_inform_warn "OML enabled but no OML configuration was given"+
        "(file: '#{res.property.oml_configfile}' - "+
        "config: '#{res.property.oml.inspect}')"
    end
    cmd += "--oml-log-level #{res.property.oml_loglevel} " unless res.property.oml_loglevel.nil?
    cmd += "--oml-log-file #{res.property.oml_logfile} " unless res.property.oml_logfile.nil?
    cmd
  end


end
