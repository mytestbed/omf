module OmfRc::Util::Libvirt
  include OmfRc::ResourceProxyDSL

  VIRSH = "/usr/bin/virsh"
  VIRTCLONE = "/usr/bin/virt-clone"

  work :define_vm_with_libvirt do |res|
    cmd = "#{VIRSH} -c #{res.property.hypervisor_uri} "+
          "define #{res.property.vm_definition}"
  end

  work :stop_vm_with_libvirt do |res|
    cmd = "#{VIRSH} -c #{res.property.hypervisor_uri} "+
          "destroy #{res.property.vm_name}"
  end

  work :run_vm_with_libvirt do |res|
    cmd = "#{VIRSH} -c #{res.property.hypervisor_uri} "+
          "start #{res.property.vm_name}"
  end

  work :delete_vm_with_libvirt do |res|
    cmd = "#{VIRSH} -c #{res.property.hypervisor_uri} "+
          "undefine #{res.property.vm_name} ; rm -rf #{res.property.image_path}"
  end
  
end
