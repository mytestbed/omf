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

  HYPERVISOR_DEFAULT = :kvm
  HYPERVISOR_URI_DEFAULT = 'qemu:///system'
  VIRTUAL_MNGT_DEFAULT = :libvirt

  IMAGE_BUILDER_DEFAULT = :vmbuilder
  VM_NAME_DEFAULT_PREFIX = "vm"
  #VM_PATH_DEFAULT = "/var/lib/libvirt/images/"
  VM_DIR_DEFAULT = "/home/thierry/experiments/omf6-dev/images"

  VMBUILDER = "/usr/bin/vmbuilder"
  VIRSH = "/usr/bin/virsh"
  VIRTCLONE = "/usr/bin/virt-clone"

  VM_OS_DEFAULT = 'ubuntu'
  VMBUILDER_DEFAULT = Hashie::Mash.new({
                      cpus: 1, mem: 512, libvirt: HYPERVISOR_URI_DEFAULT,
                      rootsize: 20000, overwrite: true,
                      ip: nil, mask: nil, net: nil, bcast: nil, 
                      gw: nil, dns: nil 
                      })
  UBUNTU_DEFAULT = Hashie::Mash.new({ 
                      suite: 'natty', arch: 'i386',
                      user: 'administrator', pass: 'omf',
                      mirror: 'http://10.0.0.200:9999/ubuntu',
                      #mirror: 'http://au.archive.ubuntu.com/ubuntu/',
                      bridge: nil,
                      #variant: 'minbase',
                      #pkg: ['openssh-server'] 
                      #pkg: ['openssh-server','sudo','inetutils-ping','host',
                      #      'net-tools','vim','gpgv'] 
                      pkg: ['openssh-server','sudo','inetutils-ping','host',
                            'net-tools','vim','gpgv',
                            'build-essential','automake', 'curl',
                            'zlib1g-dev','libxslt-dev','libxml2-dev',
                            'libssl-dev','iw'] 
                      })
  OMF_DEFAULT = Hashie::Mash.new({
                      server: 'srv.mytestbed.net', 
                      user: nil, password: nil,
                      topic: nil
                      })

  hook :before_ready do |res|
    res.property.use_sudo ||= true
    res.property.hypervisor ||= HYPERVISOR_DEFAULT
    res.property.hypervisor_uri ||= HYPERVISOR_URI_DEFAULT
    res.property.virt_mngt ||= VIRTUAL_MNGT_DEFAULT
    res.property.img_builder ||= IMAGE_BUILDER_DEFAULT

    res.property.action ||= :stop
    res.property.ready ||= false
    res.property.enable_omf ||= true
    res.property.vm_name ||= "#{VM_NAME_DEFAULT_PREFIX}_#{Time.now.to_i}"
    res.property.image_directory ||= VM_DIR_DEFAULT
    res.property.image_path ||= "#{VM_DIR_DEFAULT}/#{res.property.vm_name}"
    res.property.vm_os ||= VM_OS_DEFAULT
    res.property.vmbuilder_opts ||= VMBUILDER_DEFAULT
    res.property.ubuntu_opts ||= UBUNTU_DEFAULT
    res.property.omf_opts ||= OMF_DEFAULT
  end

  %w(vmbuilder ubuntu omf).each do |prefix|
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

  # configure :vm_opts do |res, opts|
  #   if opts.kind_of? Hash
  #     res.property.vm_opts = res.property.vm_opts.empty? ? \
  #       VM_DEFAULT.merge(opts) : res.property.vm_opts.merge(opts)
  #   else
  #     res.log_inform_error "VM option configuration failed! "+
  #       "Options not passed as Hash (#{opts.inspect})"
  #   end
  #   res.property.vm_opts
  # end

  # configure :ubuntu_opts do |res, opts|
  #   if opts.kind_of? Hash
  #     res.property.ubuntu_opts = res.property.ubuntu_opts.empty? ? \
  #       UBUNTU_DEFAULT.merge(opts) : res.property.ubuntu_opts.merge(opts)
  #   else
  #     res.log_inform_error "Ubuntu VM option configuration failed! "+
  #       "Options not passed as Hash (#{opts.inspect})"
  #   end
  #   res.property.ubuntu_opts
  # end

  configure :action do |res, value|
    case value.to_s.downcase.to_sym
    when :build then res.switch_to_build
    when :define then res.switch_to_define
    when :stop then res.switch_to_stop
    when :run then res.switch_to_run
    when :delete then res.switch_to_delete
    when :clone then res.switch_to_delete
    end
    res.property.state
  end

  work('switch_to_build') do |res|
    if res.property.ready 
      res.log_inform_warn "Trying to build an already built VM, "+
        "make sure to have the 'overwrite' property set to true!"
    else
      `mkdir -p #{res.property.image_path}`
      res.log_inform_error "Cannot create VM directory at "+
        "#{res.property.image_path}" if $?.exitstatus != 0
    end
    if res.property.action.to_sym == :stop && File.directory?(res.property.image_path)
      cmd = res.send("build_img_#{res.property.img_builder}")
      logger.info "Building VM with: '#{cmd}'"
      result = `#{cmd} 2>&1`
      if $?.exitstatus != 0
        res.log_inform_error "Cannot build VM image: '#{result}'"
      else
         res.property.ready = true
         logger.info "VM image built successfully!"
         res.inform(:status, Hashie::Mash.new({:status => {:ready => true}}))
      end
    else
      res.log_inform_error "Cannot build VM image, as VM is not stopped or "+
        "its directory does not exist (VM path: '#{res.property.image_path}')"
    end
  end

  work('switch_to_define') do |res|
  end

  work('switch_to_stop') do |res|
    if res.property.action.to_sym == :run
      cmd = res.send("#{res.property.virt_mngt}_stop")
      logger.info "Stopping VM with: '#{cmd}'"
      result = `#{cmd} 2>&1`
      if $?.exitstatus != 0
        res.log_inform_error "Cannot stop VM: '#{result}'"
      else
        res.property.action.to_sym == :stop
      end
    else
      res.log_inform_warn "Cannot stop VM: it is not running "+
        "(VM name: '#{res.property.vm_name}')"
    end
  end

  work('switch_to_run') do |res|
    if res.property.action.to_sym == :stop && res.property.ready
      cmd = res.send("#{res.property.virt_mngt}_run")
      logger.info "Running VM with: '#{cmd}'"
      result = `#{cmd} 2>&1`
      if $?.exitstatus != 0
        res.log_inform_error "Cannot run VM: '#{result}'"
      else
        res.property.action.to_sym == :run
      end
    else
      res.log_inform_warn "Cannot run VM: it is not stopped or ready yet "+
        "(VM name: '#{res.property.vm_name}')"
    end
  end

  work('switch_to_delete') do |res|
    if res.property.action.to_sym == :stop && res.property.ready     
      cmd = res.send("#{res.property.virt_mngt}_delete")
      logger.info "Deleting VM with: '#{cmd}'"
      result = `#{cmd} 2>&1`
      if $?.exitstatus != 0
        res.log_inform_error "Cannot delete VM: '#{result}'"
      else
        res.property.action.to_sym = :stop
        res.property.ready = false
      end
    else
      res.log_inform_warn "Cannot delete VM: it is not stopped or ready yet "+
        "(VM name: '#{res.property.vm_name}')"
    end
  end

  work('build_img_vmbuilder') do |res|
    # Construct the vmbuilder command
    cmd = "cd #{res.property.image_path} ; "
    cmd += res.property.use_sudo ? "sudo " : ""
    cmd += "#{VMBUILDER} #{res.property.hypervisor} #{res.property.vm_os} "+
            "--hostname #{res.property.vm_name} "
    # Add vmbuilder options
    res.property.vmbuilder_opts.each do |k,v|
      if k.to_sym == :overwrite
        cmd += "-o " if v
      else
        cmd += "--#{k.to_s} #{v} " unless v.nil?
      end
    end
    # Add OS-specific options, eg. call 'vmbuilder_ubuntu_opts' if OS is ubuntu
    cmd = res.send("vmbuilder_#{res.property.vm_os}_opts", cmd)
    # Add first boot script
    firstboot = "#{res.property.image_path}/firstboot.sh"
    f = File.open(firstboot,'w')
    f << <<-eos
#!/bin/bash
# Fix DNS setting
echo 'nameserver 10.0.0.200' >> /etc/resolv.conf
# Regenerate SSH key for each image instance
rm /etc/ssh/ssh_host*key*
dpkg-reconfigure -fnoninteractive -pcritical openssh-server
eos
    # Add OMF install to that first boot script
    res.vmbuilder_enable_omf(f) if res.property.enable_omf
    f.close
    cmd += "--firstboot #{firstboot}"
  end

  work('vmbuilder_ubuntu_opts') do |res,cmd|
    res.property.ubuntu_opts.each do |k,v|
      if k.to_sym == :pkg 
        v.each { |p| cmd += "--addpkg #{p} "} if v.length > 0
      else
        cmd += "--#{k.to_s} #{v} " unless v.nil?
      end
    end
    cmd
  end

  work('vmbuilder_enable_omf') do |res,file|
    u = res.property.omf_opts.user.nil? ? \
      "#{res.property.vm_name}" : res.property.omf_opts.user
    p = res.property.omf_opts.password.nil? ? \
      "123456" : res.property.omf_opts.password
    t = res.property.omf_opts.topic.nil? ? \
      "#{res.property.vm_name}_node" : res.property.omf_opts.topic
    file << <<-eos
# Install OMF 6 RC
curl -L https://get.rvm.io | bash -s stable
source /usr/local/rvm/scripts/rvm
command rvm install 1.9.3
PATH=$PATH:/usr/local/rvm/rubies/ruby-1.9.3-p194/bin/ 
source /usr/local/rvm/environments/ruby-1.9.3-p194
gem install omf_rc --pre --no-ri --no-rdoc 
# HACK
# Right now we dont have a Ubuntu startup script for OMF6 RC
# Do this quick hack in the meantime
echo '#!/bin/bash' >>/etc/rc2.d/S99omf_rc
echo 'source /etc/profile.d/rvm.sh' >>/etc/rc2.d/S99omf_rc
echo 'source /usr/local/rvm/environments/ruby-1.9.3-p194' >>/etc/rc2.d/S99omf_rc
echo 'nohup omf_rc -u #{u} -p #{p} -t #{t} -s #{res.property.omf_opts.server} &>>/tmp/omf_rc.log &' >>/etc/rc2.d/S99omf_rc
chmod 555 /etc/rc2.d/S99omf_rc
/etc/rc2.d/S99omf_rc
eos
  end

  work('libvirt_stop') do |res|
    cmd = "#{VIRSH} -c #{res.property.hypervisor_uri} "+
          "destroy #{res.property.vm_name}"
  end

  work('libvirt_run') do |res|
    cmd = "#{VIRSH} -c #{res.property.hypervisor_uri} "+
          "start #{res.property.vm_name}"
  end

  work('libvirt_delete') do |res|
    cmd = "#{VIRSH} -c #{res.property.hypervisor_uri} "+
          "undefine #{res.property.vm_name} ; rm -rf #{image_path}"
  end

end
