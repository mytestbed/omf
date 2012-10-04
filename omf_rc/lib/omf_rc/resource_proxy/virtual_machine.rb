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

  VMBUILDER = "/usr/bin/vmbuilder"
  VIRSH = "/usr/bin/virsh"
  VM_NAME_DEFAULT = "anonymous_vm"
  #VM_PATH_DEFAULT = "/var/lib/libvirt/images/"
  VM_PATH_DEFAULT = "/home/thierry/experiments/omf6-dev/images"
  VM_TYPE_DEFAULT = 'kvm'
  VM_OS_DEFAULT = 'ubuntu'
  VM_OPTS_DEFAULT = { cpus: 1, mem: 512, libvirt: 'qemu:///system',
                      rootsize: 20000, overwrite: false,
                      ip: nil, mask: nil, net: nil, bcast: nil, 
                      gw: nil, dns: nil }
  UBUNTU_DEFAULT = { suite: 'natty', arch: 'i386',
                      user: 'administrator', pass: 'omf',
                      mirror: 'http://10.0.0.200:9999/ubuntu',
                      #mirror: 'http://au.archive.ubuntu.com/ubuntu/',
                      variant: 'minbase',
                      bridge: nil,
                      pkg: ['openssh-server'] }

  hook :before_ready do |res|
    res.property.use_sudo ||= true
    res.property.state ||= :stop
    res.property.built ||= false
    res.property.vm_name ||= "#{VM_NAME_DEFAULT}_#{Time.now.to_i}"
    res.property.vm_directory ||= VM_PATH_DEFAULT
    res.property.vm_type ||= VM_TYPE_DEFAULT
    res.property.vm_os ||= VM_OS_DEFAULT
    res.property.vm_opts ||= Hash.new
    res.property.ubuntu_opts ||= Hash.new
  end

  configure :state do |res, value|
    case value.to_s.downcase.to_sym
    when :build then res.switch_to_build
    when :stop then res.switch_to_stop
    when :run then res.switch_to_run
    end
    res.property.state
  end

  work('build_ubuntu') do |res,cmd|
    opts = UBUNTU_DEFAULT.merge(res.property.ubuntu_opts.to_hash(:symbolize_keys => true))
    opts.each do |k,v|
      if k == :pkg 
        v.each { |p| cmd += "--addpkg #{p} "} if v.length > 0
      else
        cmd += "--#{k.to_s} #{v} " unless v.nil?
      end
    end
    cmd
  end

  work('switch_to_build') do |res|
    vm_path = "#{res.property.vm_directory}/#{res.property.vm_name}"
    if res.property.state.to_sym == :stop
      `mkdir -p #{vm_path}`
      if $?.exitstatus != 0
        res.log_inform_error "Cannot create VM directory at #{vm_path}"
      else
        # Construct the vmbuilder command
        cmd = "cd #{vm_path} ; "
        cmd += res.property.use_sudo ? "sudo " : ""
        cmd += "#{VMBUILDER} #{res.property.vm_type} #{res.property.vm_os} "+
                "--hostname #{res.property.vm_name} "
        # Add vmbuilder options, use defaults for undefined ones
        opts = VM_OPTS_DEFAULT.merge(res.property.vm_opts.to_hash(:symbolize_keys => true))
        opts.each do |k,v|
          if k == :overwrite
            cmd += "-o " if v
          else
            cmd += "--#{k.to_s} #{v} " unless v.nil?
          end
        end
        # Add OS-specific options, e.g. call 'build_ubuntu' if OS is ubuntu
        cmd = res.send("build_#{res.property.vm_os}", cmd)
        logger.info "Building VM with: '#{cmd}'"
        result = `#{cmd}`
        if $?.exitstatus != 0
          res.log_inform_error "Cannot build VM: #{result}"
        else
          res.property.built = true
          logger.info "VM Built successfully!"
        end
      end
    end
  end

  work('switch_to_stop') do |res|
    if res.property.state.to_sym == :run
      opts = VM_OPTS_DEFAULT.merge(res.property.vm_opts.to_hash(:symbolize_keys => true))
      cmd = "#{VIRSH} -c #{opts[:libvirt]} destroy #{res.property.vm_name}"
    end
  end

  work('switch_to_run') do |res|
    if res.property.state.to_sym == :stop && res.property.built
      opts = VM_OPTS_DEFAULT.merge(res.property.vm_opts.to_hash(:symbolize_keys => true))
      cmd = "#{VIRSH} -c #{opts[:libvirt]} start #{res.property.vm_name}"
    end
  end

end
