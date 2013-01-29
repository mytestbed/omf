
# Communication setup
Comm.init(:xmpp)

def create_vm(vm_name, host)
  opts = {
    name: 'my_VM_123',
    ubuntu_opts: { bridge: 'br0' }, 
    vmbuilder_opts: {
      ip: '10.0.0.240', 
      net: '10.0.0.0',
      bcast: '10.255.255.255',
      mask: '255.0.0.0',
      gw: '10.0.0.200',
      dns: '10.0.0.200'
    }
  }
  host.create(:vm, opts) do |msg|
    if msg.success?
      vm = msg.resource
      on_vm_created(vm, host)
    else
      logger.error "Resource creation failed - #{msg[:reason]}"
    end
  end
end

def on_vm_created(vm, host)
  logger.info "Created #{vm}"
  vm.on_inform_status do |msg|
    msg.each_property do |name, value|
      logger.info "#{name} => #{value}"
    end
    if vm.state == :running
      puts "HURRAY, vm '#{vm}' is up and running"
    end
  end
  
  vm.after(10) do
    vm.configure(state: :run)
  end
end

OmfCommon.eventloop.run do |el|
  OmfCommon.comm.on_connected do |comm|
    # Get handle on existing entity
    comm.subscribe('host_1') do |host|
    
      host.on_inform_failed do |msg|
        logger.error msg
      end
      # wait until host topic is ready to receive
      host.on_subscribed do
        create_vm(host)
      end
    end
    
    el.after(20) { el.stop }
  end
end


puts "DONE"


