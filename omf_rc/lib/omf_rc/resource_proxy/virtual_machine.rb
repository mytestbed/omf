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
# This module defines a Resource Proxy (RP) for a Virtual Machine Factory
#
# Utility dependencies: common_tools
#
# This VM Factory Proxy has the following properties:
#

module OmfRc::ResourceProxy::VirtualMachine
  include OmfRc::ResourceProxyDSL 

  register_proxy :virtual_machine
  utility :common_tools

  hook :before_ready do |res|
    res.property.state ||= :unbuild
    res.property.vm_type ||= "kvm"
    res.property.vm_os ||= "ubuntu"
    res.property.vm_os_version ||= "natty"
    res.property.arch ||= "i386"
    res.property.hostname ||= "vm-#{Time.now.to_i}"
    res.property.memory ||= 512
    res.property.cpus ||= 1
    res.property.rootsize ||= 20000
    res.property.user ||= "administrator"
    res.property.pass ||= "omf"
    res.property.libvirt ||= "qemu:///system"
    res.property.overwrite ||= false
    res.property.ip ||= nil
    res.property.netmask ||= nil
    res.property.network ||= nil
    res.property.broadcast ||= nil
    res.property.gateway ||= nil
    res.property.dns ||= nil
    res.property.bridge ||= nil
    res.property.ubuntu_mirror ||= "http://au.archive.ubuntu.com/ubuntu/"
    res.property.ubuntu_variant ||= "minbase"
    res.property.ubuntu_pkg ||= []
  end

  configure :state do |res, value|
    case value.to_s.downcase.to_sym
    when :build then res.switch_to_build
    when :stop then res.switch_to_stop
    when :run then res.switch_to_run
    end
    res.property.state
  end

  work('switch_to_build') do |res|
    unless res.property.state.to_sym == :run
		end
	end

  work('switch_to_stop') do |res|
    if res.property.state.to_sym == :run
		end
	end

  work('switch_to_run') do |res|
    if res.property.state.to_sym == :build
		end
	end

end
