# $Id: ifconfig.rb,v 1.4 2004/02/21 07:44:59 daniel Exp $
#
class Ifconfig
  include Enumerable

  #
  # Give hash like access to the interfaces
  #
  def [](iface)
    return @ifaces[iface]
  end

  def each( &block )
    return @ifaces.each_value( &block )
  end

  # return list of interface names
  #
  def interfaces
    return @ifaces.keys
  end

  # returns array of interface text blocks
  #
  def split_interfaces(text)
    ifaces = []
    text.split("\n").each { |line|
      ifaces[ifaces.length] = "" if line =~ /^\S/
      ifaces[ifaces.length-1] += line.rstrip+"\n"
    }
    return ifaces
  end

  # Given an interface block
  # returns the name of an interface (eth0, eth0:1 ppp0, etc.)
  #
  def get_iface_name(text)
    name = Regexp.compile(/^(\S+)/).match(text)[1]
    # strip trailing :, for bsd sun
    name.sub!(/:$/,'')
    return name
  end

  def to_s
    s=""
    self.interfaces.sort.each { |k|
      s += @ifaces[k].to_s
      s += "\n-------------------------\n"
    }
    return s
  end

  # return list of all addresses on all interfaces reported by ifconfig
  #
  def addresses(type=nil)
    addr = []
    @ifaces.each_value { |iface|
      addr += iface.addresses
    }
    return addr
  end

  # returns array of arrays
  # [ [address , type ] ]
  #
  def addrs_with_type
    addr = []
    @ifaces.each_value { |iface|
      addr += iface.addrs_with_type
    }
    return addr
  end
end
