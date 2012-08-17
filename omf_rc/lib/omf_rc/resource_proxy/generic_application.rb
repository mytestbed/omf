#
# Copyright (c) 2012 National ICT Australia (NICTA), Australia
##
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

#
# This module defines a Resource Proxy (RP) for a Generic Application
# Utility dependencies: platform_toos, common_tools
#
#
module OmfRc::ResourceProxy::GenericApplication
  include OmfRc::ResourceProxyDSL 
  require 'omf_common/exec_app'

  register_proxy :generic_application
  utility :platform_tools
  utility :common_tools

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
        OmfCommon::Message.inform('APP_EVENT') do |message|
          message.property('event' , event_type.to_s.upcase)
          message.property('app' , app_id)
          message.property('msg' , "#{msg}")
          message.property('seq' , "#{res.property.event_sequence}")
        end)
      res.property.event_sequence += 1
      res.property.installed = true if app_id.include?("_INSTALL") &&
                                       event_type.to_s.include?('DONE.OK')
  end

  # Request the basic properties of this Generic Application RP. These
  # properties are:
  #
  # @param [String] binary_path the path to the binary of this app
  # @param [String] pkg_tarball the URI of the installation tarball of this app 
  # @param [String] pkg_ubuntu the name of the Ubuntu package for this app
  # @param [String] pkg_fedora the name of the Fedora package for this app
  # @param [String] state the state of this Application RP 
  #                 (stop, start, pause, install)
  # @param [Boolean] installed is this application installed? (true/false)
  # @param [Boolean] force_tarball_install if true then force the installation 
  #                  from tarball even if other distribution-specific 
  #                  installation are available (default = false)
  # @param [Boolean] map_err_to_out if true then map StdErr to StdOut for this 
  #                  app (default = false)
  # @param [Symbol] platform the OS platform where this app is running
  #
  %w(binary_path pkg_tarball pkg_ubuntu pkg_fedora state installed \
    force_tarball_install map_err_to_out tarball_install_path).each do |prop|
    request(prop) { |res| res.property[prop].to_s }
  end
  
  # Request the platform properties of this Generic Application RP
  #
  # @see OmfRc::ResourceProxy::GenericApplication
  #
  request :platform do |res|
    res.property.platform = detect_platform if res.property.platform.nil?
    res.property.platform.to_s
  end

  # Configure the basic properties of this Generic Application RP
  #
  # @see OmfRc::ResourceProxy::GenericApplication
  #
  %w(binary_path pkg_tarball pkg_ubuntu pkg_fedora force_tarball_install \
    map_err_to_out tarball_install_path).each do |prop|
    configure(prop) { |res, value| res.property[prop] = value }
  end

  # Configure the state of this Generic Application RP. The valid states are
  # stop, run, pause, install. The semantic of each states are:
  # - stop: the initial state for an Application RP, and the final state for 
  #         an applicaiton RP, for which the application instance finished 
  #         its execution or its installation
  # - run: upon entering in this state, a new instance of the application is 
  #        started, the Application RP stays in this state until the
  #        application instance is finished or paused. The Application RP can
  #        only enter this state from a previous 'pause' or 'stop' state.
  # - pause: upon entering this state, the currently running instance of this
  #          application should be paused (it is the responsibility of 
  #          specialised Application Proxy to ensure that! The default Generic
  #          Application Proxy does nothing to the application instance when
  #          entering this state). The Application RP can only enter this 
  #          state from a previous 'run' state.
  # - install: upon entering in this state, a new installation of the
  #            application will be performed by the Application RP, which will
  #            stay in this state until the installation is finished. The 
  #            Application RP can only enter this state from a previous 'stop'
  #            state, and can only enter a 'stop' state once the installation
  #            is finished.
  #            Supported install methods are: Tarball, Ubuntu, and Fedora
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
      ExecApp.new(res.property.app_id, res, 
                  res.property.binary_path, 
                  res.property.map_err_to_out)
                  res.property.state = :run 
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


end
