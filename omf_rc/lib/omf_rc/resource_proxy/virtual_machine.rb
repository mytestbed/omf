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
# - :use_sudo, use 'sudo' when running VM-related commands (default => true)
# - :hypervisor, the hypervisor to use (default => HYPERVISOR_DEFAULT)
# - :hypervisor_uri, the URI of the hypervisor to use (default => HYPERVISOR_URI_DEFAULT)
# - :virt_mngt, the virtualisation management tool to use (default => VIRTUAL_MNGT_DEFAULT)
# - :img_builder, the tool to use to build VM image (default => IMAGE_BUILDER_DEFAULT)
# - :state, the current state of this VM Proxy (default => :stopped)
# - :ready, is the VM for this Proxy ready to be run? (default => false)
# - :action, the next action to perform on this VM Proxy (build, define, stop, run, delete, attach, or clone_from)
# - :vm_name, the name of this VM (default => VM_NAME_DEFAULT_PREFIX + "_" + current time)
# - :image_directory, the directory holding this VM's disk image (default => VM_DIR_DEFAULT)
# - :image_path, the full path to this VM's disk image (default => image_directory + vm_name)
# - :vm_os, the OS to use on this VM (default => VM_OS_DEFAULT)
# - :vm_definition, the path to an definition file for this VM
# - :vm_original_clone, the name of an existing VM that may be used as a template for this one
# - :enable_omf, is an OMF Resource Proxy (to be) installed on this VM? (default => true)
# - :omf_opts, the options to set for the OMF v6 RC on this VM (default => OMF_DEFAULT)
#
# USAGE NOTES:
#
# A VirtualMachine Proxy is an interface to an underlying VM resource on a 
# physical resource. When a VM Proxy is created, it is not necessarily yet
# associated with such a VM resource (unless the original 'create' command
# for this VM Proxy had some optional property configuration as described
# below). 
# 
# Thus you must associate this VM Proxy with an underlying VM resource. This
# could be done in the following manner:
# - A) build a brand new VM resource, including building a new disk image for it
# - B) build a new VM resource from an existing VM definition file
# - C) build a new VM resource by cloning an existing VM resource
# - D) attach a VM resource (existing already on the system) to this VM Proxy
# 
# Once the VM Proxy is associated to an underlying VM resource, it can 
# start/stop it or de-associated ('delete' action) from it, according to the
# following state diagram:
#      
#                     build,
#                  clone,define,
#    +---------+      attach     +---------+     run     +---------+
#    |         |--------|------->| stopped |------|----->|         |
#    | stopped |                 | + ready |             | running |
#    |         |<-------|--------|         |<-----|------|         |
#    +---------+     delete      +---------+     stop    +---------+
# 
#
# Some examples of message sequences to send to a freshly created VM proxy
# 'new_VMP' to realise each of the above association cases are given in the 
# 'Examples' section below.
#
# @example Case A: create and then run a new VM with a new disk image using all the default settings:
#
#    # Communication setup
#    comm = Comm.new(:xmpp)
#    vm_topic = comm.get_topic('new_VMP')
#
#    # Define the messages to publish
#    conf_vm_name = comm.configure_message([vm_name: 'my_VM_123'])
#    conf_vm_options = comm.configure_message([
#                           ubuntu_opts: { bridge: 'br0' }, 
#                           vmbuilder_opts: {ip: '10.0.0.240', 
#                                            net: '10.0.0.0',
#                                            bcast: '10.255.255.255',
#                                            mask: '255.0.0.0',
#                                            gw: '10.0.0.200',
#                                            dns: '10.0.0.200'} ])
#    conf_vm_build = comm.configure_message([action: :build])
#    conf_vm_run = comm.configure_message([action: :run])
#
#    # Define a new event to run the VM resource once it is 'ready'
#    vm_topic.on_message do |m|
#      if (m.operation == :inform) && (m.read_content("itype") == 'STATUS') && m.read_property('ready')
#        conf_vm_run.publish vm_topic.id    
#      end
#    end
#
#    # Publish the defined messages
#    conf_vm_name.publish vm_topic.id    
#    conf_vm_options.publish vm_topic.id    
#    conf_vm_build.publish vm_topic.id    
#
# @example Case B: create and run a new VM using an existing definition file:
# 
#    # Do the communication setup as in the above example...
#
#    # Define the messages to publish
#    conf_vm_name = comm.configure_message([vm_name: 'my_VM_123'])
#    conf_vm_definition = comm.configure_message([vm_definition: '/home/me/my_vm_definition.xml'])
#    conf_vm_define = comm.configure_message([action: :define])
#    conf_vm_run = comm.configure_message([action: :run])
#
#    # Define a new event to run the VM resource as in the above example...
#
#    # Publish the defined messages
#    conf_vm_name.publish vm_topic.id    
#    conf_vm_definition.publish vm_topic.id    
#    conf_vm_define.publish vm_topic.id 
#
# @example Case C: create and run a new VM by cloning an existing VM:
# 
#    # Do the communication setup as in the above example...
#
#    # Define the messages to publish
#    # Note that the existing VM to clone from must be defined and known
#    # by the virtualisation management tool set in the :virt_mngt property
#    conf_vm_name = comm.configure_message([vm_name: 'my_VM_123'])
#    conf_vm_original_name: comm.configure_message([vm_original_clone: 'existing_VM_456']),
#    conf_vm_clone = comm.configure_message([action: :clone_from])
#    conf_vm_run = comm.configure_message([action: :run])
#
#    # Define a new event to run the VM resource as in the above example...
#
#    # Publish the defined messages
#    conf_vm_name.publish vm_topic.id    
#    conf_vm_original_name.publish vm_topic.id    
#    conf_vm_clone.publish vm_topic.id 
#
# @example Case D: associate an existing VM to this VM Proxy and run it:
# 
#    # Do the communication setup as in the above example...
#
#    # Define the messages to publish
#    # Note that the existing VM to associate to this VM Proxy must be defined 
#    # and known by the virtualisation management tool set in the :virt_mngt property
#    conf_vm_name = comm.configure_message([vm_name: 'my_VM_123'])
#    conf_vm_attach: comm.configure_message([action: :attach]),
#    conf_vm_run = comm.configure_message([action: :run])
#
#    # Define a new event to run the VM resource as in the above example...
#
#    # Publish the defined messages
#    conf_vm_name.publish vm_topic.id    
#    conf_vm_attach.publish vm_topic.id    
#
# EXTENSION NOTES:
#
# By default this VM Proxy interacts with a KVM hypervisor using the libvirt 
# virtualisation tools (i.e. virsh, virt-clone) to manipulate Ubuntu-based VMs,
# which may be built using ubuntu's vmbuilder tool. However, one can extend this 
# to support other hypervisors and tools. 
#
# - to extend:
#   - create one/many utility file(s) to hold the code of your extension,
#     e.g. "myext.rb"
#   - assuming you will use the "foo" virtualisation management tools, and 
#     the "bar" image building tool, then you must define within your utility 
#     file(s) the following work methods, which should perform the obvious
#     tasks mention by their names. In addition they must return 'true' if 
#     their tasks were successfully performed, or 'false' otherwise. See the
#     provided libvirt and vmbuilder utility files for some examples.
#     - define_vm_with_foo 
#     - stop_vm_with_foo 
#     - run_vm_with_foo 
#     - attach_vm_with_foo 
#     - clone_vm_with_foo 
#     - delete_vm_with_foo
#     - build_img_with_bar
#
# - to use that extension:
#   - require that/these utility files
#   - set the virt_mngt, virt_mngt properties to "foo", "bar" respectively
#
# @see OmfRc::Util::Libvirt
# @see OmfRc::Util::Vmbuilder
module OmfRc::ResourceProxy::VirtualMachine
  include OmfRc::ResourceProxyDSL 

  register_proxy :virtual_machine
  utility :common_tools
  utility :libvirt
  utility :vmbuilder

  # Default Hypervisor to use
  HYPERVISOR_DEFAULT = :kvm
  # Default URI for the default Hypervisor
  HYPERVISOR_URI_DEFAULT = 'qemu:///system'
  # Default virtualisation management tool to use
  VIRTUAL_MNGT_DEFAULT = :libvirt
  # Default VM image building tool to use
  IMAGE_BUILDER_DEFAULT = :vmbuilder
  # Default prefix to use for the VM's name
  VM_NAME_DEFAULT_PREFIX = "vm"
  # Default directory to store the VM's disk image
  VM_DIR_DEFAULT = "/home/thierry/experiments/omf6-dev/images"
  # Default OS used on this VM
  VM_OS_DEFAULT = 'ubuntu'
  # Default OMF v6 parameters for the Resource Controller on the VM
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

  # Configure the OMF property of this VM Proxy.
  # These are the parameters to pass to an OMF v6 Resource Controller
  # installed (or to be installed) on the VM associated to this VM Proxy.
  #
  # @yieldparam [Hash] opts a hash with the OMF RC parameters
  #             - server (String) the PubSub sever for this OMF RC to connect to
  #             - user (String) the username to use for that server
  #             - password (String) the password to use for that server
  #             - topic (String) the PubSub topic to subscribe to
  #
  configure :omf_opts do |res, opts|
    if opts.kind_of? Hash
      if res.property.omf_opts.empty?
        res.property.omf_opts = OMF_DEFAULT.merge(opts)
      else 
        res.property.omf_opts = res.property.omf_opts.merge(opts)
      end
    else
      res.log_inform_error "OMF option configuration failed! "+
        "Options not passed as Hash (#{opts.inspect})"
    end
    res.property.omf_opts
  end

  # Configure the name for the VM associated to this VM Proxy.
  # Changing this name will also change the path for the VM's disk image:
  #    image_path = image_directory + "/" + vm_name
  #
  # @yieldparam [String] name the name of the VM 
  #
  configure :vm_name do |res, name|
    res.property.image_path = "#{res.property.image_directory}/#{name}"
    res.property.vm_name = name            
  end

  # Configure the directory for the disk image of the VM associated to this 
  # VM Proxy.
  # Changing this directory will also change the path for the VM's disk image:
  #    image_path = image_directory + "/" + vm_name
  #
  # @yieldparam [String] name the name of the directory 
  #
  configure :image_directory do |res, name|
    res.property.image_path = "#{name}/#{res.property.vm_name}"
    res.property.image_directory = name            
  end

  # Configure the next action to execute for this VM Proxy.
  # Available actions are: build, define, stop, run, delete, attach, clone_from.
  # For details about these actions, refer to the overview description at the
  # start of this file.
  #
  # @yieldparam [String] value the name of the action
  #
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
