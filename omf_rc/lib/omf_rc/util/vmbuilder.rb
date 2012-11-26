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
# This module defines the command specifics to build a VM image using
# the vmbuilder tool
#
# Utility dependencies: common_tools
#

module OmfRc::Util::Vmbuilder
  include OmfRc::ResourceProxyDSL

  VMBUILDER = "/usr/bin/vmbuilder"

  VMBUILDER_DEFAULT = Hashie::Mash.new({
                      cpus: 1, mem: 512,
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

  property :vmbuilder_opts, :default => VMBUILDER_DEFAULT
  property :ubuntu_opts, :default => UBUNTU_DEFAULT

  %w(vmbuilder ubuntu).each do |prefix|
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

  %w(vmbuilder ubuntu).each do |prefix|
    prop = "#{prefix}_opts"
    request(prop) do |res, opts|
      if res.property[prop].empty?
        res.property[prop] = res.send("#{prefix}_DEFAULT")
      else 
        res.property[prop]
      end
    end
  end

  work :build_img_with_vmbuilder do |res|
    # Construct the vmbuilder command
    `mkdir -p #{res.property.image_path}`
    if $?.exitstatus != 0
      msg = "Cannot create VM directory at #{res.property.image_path}"
      res.log_inform_error msg
      cmd = msg
    else
      cmd = "cd #{res.property.image_path} ; "
      cmd += res.property.use_sudo ? "sudo " : ""
      cmd += "#{VMBUILDER} #{res.property.hypervisor} #{res.property.vm_os} "+
              "--libvirt #{res.property.hypervisor_uri} "+
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
      cmd = res.send("build_img_with_#{res.property.vm_os}", cmd)
      # Add first boot script
      firstboot = "#{res.property.image_path}/firstboot.sh"
      res.send("build_firstboot_for_#{res.property.vm_os}", firstboot)
      # Return the fully constructed command line
      cmd += "--firstboot #{firstboot}"
    end
    logger.info "Building VM with: '#{cmd}'"
    result = `#{cmd} 2>&1`
    if $?.exitstatus != 0
      res.log_inform_error "Cannot build VM image: '#{result}'"
      false
    else
      logger.info "VM image built successfully!"
      true
    end
  end

  work :build_img_with_ubuntu do |res,cmd|
    res.property.ubuntu_opts.each do |k,v|
      if k.to_sym == :pkg 
        v.each { |p| cmd += "--addpkg #{p} "} if v.length > 0
      else
        cmd += "--#{k.to_s} #{v} " unless v.nil?
      end
    end
    cmd
  end

  work :build_firstboot_for_ubuntu do |res,file|
    f = File.open(file,'w')
    f << <<-eos
#!/bin/bash
# Fix DNS setting
echo 'nameserver #{res.property.vmbuilder_opts.dns}' >> /etc/resolv.conf
# Regenerate SSH key for each image instance
rm /etc/ssh/ssh_host*key*
dpkg-reconfigure -fnoninteractive -pcritical openssh-server
eos
    # Add OMF install to that first boot script
    if res.property.enable_omf
      u = res.property.omf_opts.user.nil? ? \
        "#{res.property.vm_name}" : res.property.omf_opts.user
      p = res.property.omf_opts.password.nil? ? \
        "123456" : res.property.omf_opts.password
      t = res.property.omf_opts.topic.nil? ? \
        "#{res.property.vm_name}_node" : res.property.omf_opts.topic
      f << <<-eos
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
    f.close
  end

end
