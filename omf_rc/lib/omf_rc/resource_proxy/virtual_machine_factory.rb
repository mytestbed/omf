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
# This VM Factory Proxy is the resource entity that can create VM Proxies.
# @see OmfRc::ResourceProxy::VirtualMachine
#
module OmfRc::ResourceProxy::VirtualMachineFactory
  include OmfRc::ResourceProxyDSL 

  register_proxy :virtual_machine_factory
  utility :common_tools

  hook :before_ready do |res|
    res.property.vms_path ||= "/var/lib/libvirt/images/"
    res.property.vm_list ||= []
  end

  hook :before_create do |res, type, opts = nil|
    if type.to_sym != :virtual_machine
      raise "This resource only creates VM! (Cannot create a resource: #{type})"
    end
  end

  hook :after_create do |res, child_res|
    logger.info "Created new child VM: #{child_res.uid}"
    res.property.vm_list << child_res.uid
  end

end
