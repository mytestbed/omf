# $Id: ifconfig.rb,v 1.5 2004/02/21 07:44:59 daniel Exp $
#

require 'lib/ifconfig/common/ifconfig'

class Ifconfig
  #
  # Can manually specify the platform (should be output of the 'uname' command)
  # and the ifconfig input
  #
  def initialize(input=nil,verbose=nil)
    if input.nil?
      cmd = IO.popen('which ifconfig').readlines[0]
      exit unless !cmd.nil?
      @ifconfig = IO.popen("/sbin/ifconfig -a").readlines.join
    else
      @ifconfig = input
    end
    @verbose = verbose

    require 'lib/ifconfig/linux/network_types'
    require 'lib/ifconfig/linux/interface_types'

    @ifaces = {}

    split_interfaces(@ifconfig).each do |iface|
      iface_name = get_iface_name(iface)
      case iface
        when /encap\:ethernet/im
          @ifaces[iface_name] = EthernetAdapter.new(iface_name,iface)
        when /encap\:Local Loopback/im
          @ifaces[iface_name] = LoopbackInterface.new(iface_name,iface)
        when /encap\:IPv6-in-IPv4/im
          @ifaces[iface_name] = IPv6_in_IPv4.new(iface_name,iface)
        when /encap\:Point-to-Point Protocol/im
          @ifaces[iface_name] = PPP.new(iface_name,iface)
        when /encap\:Serial Line IP/im
          @ifaces[iface_name] = SerialLineIP.new(iface_name,iface)
        else
          puts "Unknown Adapter Type on Linux: #{iface}" if @verbose
      end
    end
  end
end
