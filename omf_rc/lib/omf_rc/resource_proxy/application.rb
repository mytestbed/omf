#
# Copyright (c) 2012 National ICT Australia (NICTA), Australia
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

#
# This module defines a Resource Proxy (RP) for an Application
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
#     (stop, run, pause, install)
# - installed (Boolean) is this application installed? (default false)
# - force_tarball_install (Boolean) if true then force the installation
#     from tarball even if other distribution-specific
#     installation are available (default false)
# - map_err_to_out (Boolean) if true then map StdErr to StdOut for this
#     app (default false)
# - platform (Symbol) the OS platform where this app is running
# - environment (Hash) the environment variables to set prior to starting 
#     this app. {k1 => v1, ...} will result in "env -i K1=v1 ... "
#     (with k1 being either a String or a Symbol)
# - OML specific properties, as defined by OML at 
#   http://oml.mytestbed.net/doc/oml/html/liboml2.html
#   http://omf.mytestbed.net/doc/oml/html/liboml2.conf.html
#
# - parameters (Hash) the command line parameters available for this app.
#     This hash is of the form: { :param1 => attribut1, ... }
#     with param1 being the id of this parameter for this Proxy and
#     with attribut1 being another Hash with the following possible
#     keys and values (all are optional):
#     :cmd (String) the command line for this parameter
#     :order (Fixnum) the appearance order on the command line, default FIFO
#     :dynamic (Boolean) parameter can be dynammically changed, default false
#     :type (Numeric|String|Boolean) this parameter's type
#     :default value given by default to this parameter
#     :value value to set for this parameter
#     :mandatory (Boolean) this parameter is mandatory, default false
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
  require 'omf_common/exec_app'

  register_proxy :application
  utility :platform_tools
  utility :common_tools

  MAX_PARAMETER_NUMBER = 1000
  DEFAULT_MANDATORY_PARAMETER = false

  hook :before_ready do |res|
    res.property.app_id ||= nil
    res.property.binary_path ||= nil
    res.property.platform ||= nil
    res.property.pkg_tarball ||= nil
    res.property.tarball_install_path ||= '/'
    res.property.force_tarball_install ||= false
    res.property.pkg_ubuntu ||= nil
    res.property.pkg_fedora ||= nil
    res.property.state ||= :stop
    res.property.installed ||= false
    res.property.map_err_to_out ||= false
    res.property.event_sequence ||= 0
    res.property.parameters ||= Hash.new
    res.property.environments ||= Hash.new
    res.property.use_oml ||= false
    res.property.oml_configfile ||= nil
    res.property.oml ||= nil
    res.property.oml_logfile ||= nil
    res.property.oml_loglevel ||= nil
    define_method("on_app_event") { |*args| process_event(self, *args) }
  end

  # This method processes an event coming from the application instance, which
  # was started by this Resource Proxy (RP). It is a callback, which is usually
  # called by the ExecApp class in OMF
  #
  # @param [AbstractResource] res this RP
  # @param [String] event_type the type of event from the app instance
  #                 (STARTED, DONE.OK, DONE.ERROR, STDOUT, STDERR)
  # @param [String] app_id the id of the app instance
  # @param [String] msg the message carried by the event
  #
  def process_event(res, event_type, app_id, msg)
      logger.info "App Event from '#{app_id}' "+
                  "(##{res.property.event_sequence}) - "+
                  "#{event_type}: '#{msg}'"
      res.property.state = :stop if event_type.to_s.include?('DONE')
      res.comm.publish(res.uid,
        OmfCommon::Message.inform('STATUS') do |message|
          message.property('status_type' , 'APP_EVENT')
          message.property('event' , event_type.to_s.upcase)
          message.property('app' , app_id)
          message.property('msg' , "#{msg}")
          message.property('seq' , "#{res.property.event_sequence}")
        end)
      res.property.event_sequence += 1
      res.property.installed = true if app_id.include?("_INSTALL") &&
                                       event_type.to_s.include?('DONE.OK')
  end

  # Request the basic properties of this Application RP. 
  # @see OmfRc::ResourceProxy::Application
  #
  %w(binary_path pkg_tarball pkg_ubuntu pkg_fedora state installed \
    force_tarball_install map_err_to_out tarball_install_path).each do |prop|
    request(prop) { |res| res.property[prop].to_s }
  end
  
  # Request the platform property of this Application RP
  # @see OmfRc::ResourceProxy::Application
  #
  request :platform do |res|
    res.property.platform = detect_platform if res.property.platform.nil?
    res.property.platform.to_s
  end

  # Configure the basic properties of this Application RP
  # @see OmfRc::ResourceProxy::Application
  #
  %w(binary_path pkg_tarball pkg_ubuntu pkg_fedora force_tarball_install \
    map_err_to_out tarball_install_path).each do |prop|
    configure(prop) { |res, value| res.property[prop] = value }
  end

  # Configure the environments property of this Application RP
  # @see OmfRc::ResourceProxy::Application
  #
  configure :environments do |res, envs|
    if envs.kind_of? Hash
      res.property.environments = res.property.environments.merge(envs)
    else
      res.log_inform_error "Environment configuration failed! "+
        "Environments not passed as Hash (#{envs.inspect})"
    end
    res.property.environments
  end

  # Configure the parameters property of this Application RP
  # @see OmfRc::ResourceProxy::Application
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
          merged_val = res.property.parameters[p].nil? ? v : res.property.parameters[p].merge(v)
          new_val = res.sanitize_parameter(p,merged_val)
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
    res.property.parameters[p]
  end

  # Configure the state of this Application RP. The valid states are
  # stop, run, pause, install. The semantic of each states are:
  #
  # - stop: the initial state for an Application RP, and the final state for
  #   an applicaiton RP, for which the application instance finished
  #   its execution or its installation
  # - run: upon entering in this state, a new instance of the application is
  #   started, the Application RP stays in this state until the
  #   application instance is finished or paused. The Application RP can
  #   only enter this state from a previous 'pause' or 'stop' state.
  # - pause: upon entering this state, the currently running instance of this
  #   application should be paused (it is the responsibility of 
  #   specialised Application Proxy to ensure that! The default
  #   Application Proxy does nothing to the application instance when
  #   entering this state). The Application RP can only enter this
  #   state from a previous 'run' state.
  # - install: upon entering in this state, a new installation of the
  #   application will be performed by the Application RP, which will
  #   stay in this state until the installation is finished. The
  #   Application RP can only enter this state from a previous 'stop'
  #   state, and can only enter a 'stop' state once the installation
  #   is finished.
  #   Supported install methods are: Tarball, Ubuntu, and Fedora
  #
  # @yieldparam [String] value the state to set this app into
  #
  configure :state do |res, value|
    case value.to_s.downcase.to_sym
    when :install then res.switch_to_install
    when :stop then res.switch_to_stop
    when :run then res.switch_to_run
    when :pause then res.switch_to_pause
    end
    res.property.state
  end

  # Swich this Application RP into the 'install' state
  # (see the description of configure :state)
  #
  work('switch_to_install') do |res|
    if res.property.state.to_sym == :stop
      if res.property.installed
        res.log_inform_warn "The application is already installed"
      else
        # Select the proper installation method based on the platform
        # and the value of 'force_tarball_install'
        res.property.state = :install
        if res.property.force_tarball_install ||
          (res.property.platform == :unknown)
          installing = res.install_tarball(res.property.pkg_tarball,
              res.property.tarball_install_path)
        elsif res.property.platform == :ubuntu
          installing = res.install_ubuntu(res.property.pkg_ubuntu)
        elsif res.property.platform == :fedora
          installing = res.install_fedora(res.property.pkg_fedora)
        end
        res.property.state = :stop unless installing
      end
    else
      # cannot install as we are not stopped
      res.log_inform_warn "Not in STOP state. Cannot switch to INSTALL state!"
    end
  end

  # Swich this Application RP into the 'stop' state
  # (see the description of configure :state)
  #
  work('switch_to_stop') do |res|
    if res.property.state == :run || res.property.state == :pause
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
            ExecApp[id].kill('KILL') unless ExecApp[id].nil?
          end
          res.property.state = :stop
        rescue => err
        end
      end
    end
  end

  # Swich this Application RP into the 'run' state
  # (see the description of configure :state)
  #
  work('switch_to_run') do |res|
    if res.property.state == :stop
      # start a new instance of this app
      res.property.app_id = res.hrn.nil? ? res.uid : res.hrn
      # we need at least a defined binary path to run an app...
      if res.property.binary_path.nil?
        res.log_inform_warn "Binary path not set! No Application to run!"
      else
        ExecApp.new(res.property.app_id, res,
                    res.build_command_line,
                    res.property.map_err_to_out)
        res.property.state = :run
      end
    elsif res.property.state == :pause
      # resume this paused app
      res.property.state = :run
      # do more things here...
    elsif res.property.state == :install
      # cannot run as we are still installing
      res.log_inform_warn "Still in INSTALL state. Cannot switch to RUN state!"
    end
  end

  # Swich this Application RP into the 'pause' state
  # (see the description of configure :state)
  #
  work('switch_to_pause') do |res|
    if res.property.state == :run
      # pause this app
      res.property.state = :pause
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
  work('dynamic_parameter_update') do |res,name,att|
    # Only update a parameter if it is dynamic and the application is running
    dynamic = false
    dynamic = att[:dynamic] if res.boolean?(att[:dynamic])
    if dynamic && res.property.state == :run
      line = ""
      line += "#{att[:cmd]} " unless att[:cmd].nil?
      line += "#{att[:value]}"
      ExecApp[res.property.app_id].stdin(line)
      logger.info "Updated parameter #{name} with value #{att[:value].inspect}"
    end
  end

  # First, convert any 'true' or 'false' strings from the :mandatory and
  # :dynamic attributs of a given parameter into TrueClass or FalseClass
  # instances.
  # Second, if that parameter is of a type Boolean, then perform the same
  # conversion on the assigned default and value of this parameter
  #
  #  @yieldparam [String] name the parameter id as known by this app
  #  @yieldparam [Hash] att the Hash holding the parameter's attributs
  #
  # [Hash] a copy of the input Hash with the above conversion performed in it
  #
  work('sanitize_parameter') do |res,name,att|
    begin
      if !att[:mandatory].nil? && !res.boolean?(att[:mandatory])
        att[:mandatory] = eval(att[:mandatory].downcase)
      end
      if !att[:dynamic].nil? && !res.boolean?(att[:dynamic])
       att[:dynamic] = eval(att[:dynamic].downcase)
      end
      if (att[:type] == 'Boolean')
        att[:value] = eval(att[:value].downcase) if !att[:value].nil? && !res.boolean?(att[:value])
        att[:default] = eval(att[:default].downcase) if !att[:default].nil? && !res.boolean?(att[:default])
      end
    rescue Exception => ex
      res.log_inform_error "Cannot sanitize the parameter '#{name}' (#{att.inspect})"
    end
    att
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
  # @yieldparam [Hash] att the Hash holding the parameter's attributs
  #
  # [Boolean] true or false
  #
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
      else # HACK: Now for all other types...
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
  # [String] the full command line
  #
  work('build_command_line') do |res|
    cmd_line = "env -i " # Start with a 'clean' environments
    res.property.environments.each do |e,v|
      val = v.kind_of?(String) ? "'#{v}'" : v
      cmd_line += "#{e.to_s.upcase}=#{val} "
    end
    cmd_line += res.property.binary_path + " "
    # Add command line parameter in their specified order if any
    sorted_parameters = res.property.parameters.sort_by {|k,v| v[:order]}
    sorted_parameters.each do |param,att|
      needed = false
      needed = att[:mandatory] if res.boolean?(att[:mandatory])
      # For mandatory parameter without a value, take the default one
      val = att[:value]
      val = att[:default] if needed && att[:value].nil?
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
  #   on the liboml2.conf man page here: 
  #   http://omf.mytestbed.net/doc/oml/latest/liboml2.conf.html
  #
  # The 'oml_configfile' case takes precedence over the 'oml' case above.
  #
  # Regardless of which case is performed, we will always set the 
  # '--oml-log-level' and '--oml-log-file' parameter on the command line if 
  # the corresponsding 'oml_logfile' and 'oml_loglevel' properties are set for
  # this application resource.
  #
  # @yieldparam [String] cmd the String to which OML parameters will be added
  #
  # [String] the resulting command line
  #
  work('build_oml_config') do |res, cmd|
    if !res.property.oml_configfile.nil?
      if File.exist?(res.property.oml_configfile)
        cmd += "--oml-config #{res.property.oml_configfile}"
      else
        res.log_inform_warn "OML enabled but OML config file does not exist"+
        "(file: '#{res.property.oml_configfile}')"
      end
    elsif !res.property.oml.nil?
      o = res.property.oml
      ofile = "/tmp/#{res.uid}-#{Time.now.to_i}.xml"
      of = File.open(ofile,'w')
      of << "<omlc experiment='#{o.experiment}' id='#{o.id}'>\n"
      o.collection.each do |c|
        of << "  <collect url='#{c.url}'>\n"
        c.streams.each do |m|
          # samples as precedence over interval
          s = ''
          s = "interval='#{m.interval}'" if m.interval
          s = "samples='#{m.samples}'" if m.samples
          of << "    <stream mp='#{m.mp}' #{s}>\n"
          m.filters.each do |f|
            line = "      <filter field='#{f.field}' "
            line += "operation='#{f.operation}' " unless f.operation.nil? 
            line += "rename='#{f.rename}' " unless f.rename.nil? 
            line += "/>\n" 
            of << line           
          end
          of << "    </stream>\n"
        end
        of << "  </collect>\n"      
      end
      of << "</omlc>"
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
