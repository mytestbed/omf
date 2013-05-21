# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

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
# This module defines the command specifics to manage VMs using the 
# virsh and virt-clone tools
#
# Utility dependencies: common_tools
#
# @see OmfRc::ResourceProxy::VirtualMachine
#
module OmfRc::Util::Libvirt
  include OmfRc::ResourceProxyDSL

  VIRSH = "/usr/bin/virsh"
  VIRTCLONE = "/usr/bin/virt-clone"

  work :execute_cmd do |res,cmd,intro_msg,error_msg,success_msg|
    logger.info "#{intro_msg} with: '#{cmd}'"
    result = `#{cmd} 2>&1`
    if $?.exitstatus != 0
      res.log_inform_error "#{error_msg}: '#{result}'"
      false
    else
      logger.info "#{success_msg}"
      true
    end
  end

  work :define_vm_with_libvirt do |res|
    cmd = "#{VIRSH} -c #{res.property.hypervisor_uri} "+
          "define #{res.property.vm_definition}"
    res.execute_cmd(cmd, "Defining VM",
      "Cannot define VM", "VM defined successfully!")
  end

  work :stop_vm_with_libvirt do |res|
    cmd = "#{VIRSH} -c #{res.property.hypervisor_uri} "+
          "destroy #{res.property.vm_name}"
    res.execute_cmd(cmd, "Stopping VM",
      "Cannot stop VM", "VM stopped successfully!")
  end

  work :run_vm_with_libvirt do |res|
    cmd = "#{VIRSH} -c #{res.property.hypervisor_uri} "+
          "start #{res.property.vm_name}"
    res.execute_cmd(cmd, "Running VM",
      "Cannot run VM", "VM running now!")
  end

  work :delete_vm_with_libvirt do |res|
    cmd = "#{VIRSH} -c #{res.property.hypervisor_uri} "+
          "undefine #{res.property.vm_name} ; rm -rf #{res.property.image_path}"
    res.execute_cmd(cmd, "Deleting VM",
      "Cannot delete VM", "VM deleted!")
  end

  work :clone_vm_with_libvirt do |res|
    cmd = "#{VIRTCLONE} --connect #{res.property.hypervisor_uri} "+
          "-n #{res.property.vm_name} -f #{res.property.image_path} "
    
    # virt-clone v 0.600.1 reports an error when running with --original-xml
    # even directly on the command line. The error is:
    # "ERROR    'NoneType' object is not iterable" 
    # TODO: find-out why we have this error
    # For now we only try to clone from a known VM name and disable the
    # option to clone it from a known XML definition
    #
    #if res.property.vm_definition != ''
    #  cmd += "--original-xml #{res.property.vm_definition}"
    #elsif res.property.vm_original_clone != ''
    
    if res.property.vm_original_clone != ''
      cmd += "--original #{res.property.vm_original_clone}"
    else
      res.log_inform_error "Cannot clone VM '#{res.property.vm_name}' as "+
        "no original VM or template definition are set "+
        "(oritinal: '#{res.property.vm_definition}' - "+
        "template: '#{res.property.vm_original_clone}')"
    end
    res.execute_cmd(cmd, "Cloning VM from '#{res.property.vm_definition}' "+
      " or '#{res.property.vm_original_clone}'",
      "Cannot clone VM", "Cloned VM successfully!")
  end

  work :attach_vm_with_libvirt do |res|
    found = false
    cmd = "#{VIRSH} -c #{res.property.hypervisor_uri} list --all"
    o = `#{cmd} 2>&1`
    o.each_line { |l| found = true if l.split(' ')[1] == res.property.vm_name }
    unless found
      res.log_inform_error "Cannot attach to the VM '#{res.property.vm_name}'"+
        " (maybe it does not exist?)"
    else
      logger.info "Now attached to existing VM '#{res.property.vm_name}'!"
    end
    found
  end

end
