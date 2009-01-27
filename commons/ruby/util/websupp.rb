require 'resolv'
require 'util/mobject'

#
# Individual interface class
#
class Interface
  @@number_of_interfaces = 0

  def initialize(name, mac, ip)
    @@number_of_interfaces += 1
    @interface = name
    @mac = mac
    @ip = ip
    if @ip != nil
    # try to get subdomain name
    @domain = @fqdn = nil
    begin
      names = Resolv.getnames("#@ip")
      names.each { |nm|
        if nm =~ /\./
          @fqdn = nm
          break
        end
      }
      return if @fqdn == nil
        a = @fqdn.split('.')
        @domain = a.slice(1..a.length).join('.')
      rescue
        @fqdn = nil
      end
    else
      @domain = nil
    end
  end

  def getDomain
    @domain
  end

  def getInterface
    @interface
  end

  def getMac
    @mac
  end

  def getIp
    @ip
  end

  def getFqdn
    @fqdn
  end

  def toString
    if @ip == nil
      "Interface #@name with [#@mac] and no IP address"
    else
      if @fqdn == nil
        "Interface #@name with [#@mac] and #@ip with no DNS entry"
      else
        "Interface #@name with [#@mac] and #@fqdn (#@ip) in #@domain"
      end
    end
  end

end

#
# handling the list of interfaces
#
class InterfaceList
  def initialize
    @interfaces = Hash.new
    @domains = Hash.new
    ifs = Array.new
    IO.popen("/sbin/ifconfig -a", "r").readlines.each { |line|
      ifs[ifs.length] = "" if line =~ /^\S/
      ifs[ifs.length-1] += line.rstrip+" "
    }
    ifs.each { |k|
      name = k[/^(\S+)/]
      name.sub!(/:$/,'')
      next unless  k =~ /encap:ethernet/im
      type = k.scan(/encap:(\S+)/)[0]
      macaddress = k.scan(/HWaddr (\S+)/)[0]
      ipaddress = k.scan(/inet addr:(\S+)/)[0]
      iface = Interface.new(name,macaddress,ipaddress)
      @interfaces[name] = iface
      if iface.getDomain != nil
        @domains[iface.getDomain] = iface
      end
    }
  end

  def getInterface( domain )
    return @domains[domain].getInterface if @domains[domain] != nil
    return nil
  end

  def getDomains
    return @domains
  end
end

class Websupp

  def Websupp.getPeerSubDomain( req )
      fqdn = req.peeraddr[2].split('.')
      domain = fqdn.slice(1..fqdn.length).join('.')
      MObject.debug('websupp', 'peer sub domain for ', fqdn, ' is ', domain)
      return domain
  end

  def Websupp.getIPAddresses( querry, domain )
    # We have to get either node name or IP address
    ip = Array.new
    nodeq = querry['node']
    if (nodeq == nil)
      ipq = querry['ip']
      # If we didn't get the node names it must be the list of IP addresses
      if (ipq==nil)
        raise "Request has to have either 'node' or 'ip' argument"
      end
      ip = ipq.split(',')
    else
      nodeq.split(',').each { |node|
        # It is the node name; get it's IP address
  name = domain == nil || domain == "" ? node : "#{node}.#{domain}"
        MObject.debug('websupp', "Looking for #{name}")
        addr = Resolv.getaddress(name)
        if (addr==nil)
          raise "Host not found '#{name}'"
        end
        ip<<addr.to_s
      }
    end
    return (ip)
  end

  def Websupp.getAddress( addr )
    begin
      ip = Resolv.getaddress(addr)
    rescue
      return nil
    end
    return ip
  end

end
