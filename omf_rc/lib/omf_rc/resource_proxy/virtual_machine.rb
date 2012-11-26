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
# Utility dependencies: common_tools, libvirt, vmbuilder
#
# This VM Proxy has the following properties:
#

module OmfRc::ResourceProxy::VirtualMachine
  include OmfRc::ResourceProxyDSL 

  register_proxy :virtual_machine
  utility :common_tools
  utility :libvirt
  utility :vmbuilder

  HYPERVISOR_DEFAULT = :kvm
  HYPERVISOR_URI_DEFAULT = 'qemu:///system'
  VIRTUAL_MNGT_DEFAULT = :libvirt
  IMAGE_BUILDER_DEFAULT = :vmbuilder

  VM_NAME_DEFAULT_PREFIX = "vm"
  VM_DIR_DEFAULT = "/home/thierry/experiments/omf6-dev/images"
  VM_OS_DEFAULT = 'ubuntu'

  OMF_DEFAULT = Hashie::Mash.new({
                server: 'srv.mytestbed.net', 
                user: nil, password: nil,
                topic: nil
                })

  property :use_sudo, :default => true
  property :hypervisor, :default => HYPERVISOR_DEFAULT
  property :hypervisor_uri, :default => HYPERVISOR_URI_DEFAULT
  property :virt_mngt, :default => VIRTUAL_MNGT_DEFAULT
  property :img_builder, :default => IMAGE_BUILDER_DEFAULT
  property :action, :default => :stop
  property :state, :default => :stopped
  property :ready, :default => false
  property :enable_omf, :default => true
  property :vm_name, :default => "#{VM_NAME_DEFAULT_PREFIX}_#{Time.now.to_i}"
  property :image_directory, :default => VM_DIR_DEFAULT
  property :image_path, :default => VM_DIR_DEFAULT
  property :vm_definition, :default => ''
  property :vm_original_clone, :default => ''
  property :vm_os, :default => VM_OS_DEFAULT
  property :omf_opts, :default => OMF_DEFAULT

  %w(omf).each do |prefix|
    prop = "#{prefix}_opts"
    configure(prop) do |res, opts|
      if opts.kind_of? Hash
        if res.property[prop].empty?
          res.property[prop] = res.send("#{prefix}_DEFAULT").merge(opts)
        else 
          res.property[prop] = res.property[prop].merge(opts)
        end
      else
        res.log_inform_error "#{prefix} option configuration failed! "+
          "Options not passed as Hash (#{opts.inspect})"
      end
      res.property[prop]
    end
  end

  configure :vm_name do |res, name|
    res.property.image_path = "#{res.property.image_directory}/#{name}"
    res.property.vm_name = name            
  end

  configure :image_directory do |res, name|
    res.property.image_path = "#{name}/#{res.property.vm_name}"
    res.property.image_directory = name            
  end

  # build, define, stop, run, delete, attach, clone_from
  configure :action do |res, value|
    act = value.to_s.downcase
    res.send("#{act}_vm")
    res.property.action = value
  end

  work :build_vm do |res|    
    res.log_inform_warn "Trying to build an already built VM, make sure to "+
      "have the 'overwrite' property set to true!" if res.property.ready
    if res.property.state.to_sym == :stopped
      res.property.ready = res.send("build_img_with_#{res.property.img_builder}")
      res.inform(:status, Hashie::Mash.new({:status => {:ready => res.property.ready}}))
    else
      res.log_inform_error "Cannot build VM image: it is not stopped"+
        "(name: '#{res.property.vm_name}' - state: #{res.property.state} "+
        "- path: '#{res.property.image_path}')"
    end
  end

  work :define_vm do |res|
    unless File.exist?(res.property.vm_definition)
        res.log_inform_error "Cannot define VM (name: "+
          "'#{res.property.vm_name}'): definition path not set "+
          "or file does not exist (path: '#{res.property.vm_definition}')"
    else
      if res.property.state.to_sym == :stopped
        res.property.ready = res.send("define_vm_with_#{res.property.virt_mngt}")
        res.inform(:status, Hashie::Mash.new({:status => {:ready => res.property.ready}}))
      else
        res.log_inform_warn "Cannot define VM: it is not stopped"+
        "(name: '#{res.property.vm_name}' - state: #{res.property.state})"
      end 
    end
  end

  work :attach_vm do |res|
    unless !res.property.vm_name.nil? || !res.property.vm_name == ""
        res.log_inform_error "Cannot attach VM, name not set"+
          "(name: '#{res.property.vm_name})'"
    else
      if res.property.state.to_sym == :stopped
        res.property.ready = res.send("attach_vm_with_#{res.property.virt_mngt}")
        res.inform(:status, Hashie::Mash.new({:status => {:ready => res.property.ready}}))
      else
        res.log_inform_warn "Cannot attach VM: it is not stopped"+
        "(name: '#{res.property.vm_name}' - state: #{res.property.state})"
      end 
    end
  end

  work :clone_from_vm do |res|
    unless !res.property.vm_name.nil? || !res.property.vm_name == "" ||
      !res.image_directory.nil? || !res.image_directory == ""
      res.log_inform_error "Cannot clone VM: name or directory not set "+
        "(name: '#{res.property.vm_name}' - dir: '#{res.property.image_directory}')"
    else
      if res.property.state.to_sym == :stopped
        res.property.ready = res.send("clone_vm_with_#{res.property.virt_mngt}")
        res.inform(:status, Hashie::Mash.new({:status => {:ready => res.property.ready}}))
      else
        res.log_inform_warn "Cannot clone VM: it is not stopped"+
        "(name: '#{res.property.vm_name}' - state: #{res.property.state})"
      end 
    end
  end

  work :stop_vm do |res|
    if res.property.state.to_sym == :running
      success = res.send("stop_vm_with_#{res.property.virt_mngt}")
      res.property.state = :stopped if success
    else
      res.log_inform_warn "Cannot stop VM: it is not running "+
        "(name: '#{res.property.vm_name}' - state: #{res.property.state})"
    end
  end

  work :run_vm do |res|
    if res.property.state.to_sym == :stopped && res.property.ready
      success = res.send("run_vm_with_#{res.property.virt_mngt}")
      res.property.state = :running if success
    else
      res.log_inform_warn "Cannot run VM: it is not stopped or ready yet "+
        "(name: '#{res.property.vm_name}' - state: #{res.property.state})"
    end
  end

  work :delete_vm do |res|
    if res.property.state.to_sym == :stopped && res.property.ready     
      success = res.send("delete_vm_with_#{res.property.virt_mngt}")
      res.property.ready = false if success
    else
      res.log_inform_warn "Cannot delete VM: it is not stopped or ready yet "+
        "(name: '#{res.property.vm_name}' - state: #{res.property.state} "+
        "- ready: #{res.property.ready}"
    end
  end

end
