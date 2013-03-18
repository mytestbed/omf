require 'hashie'
require 'cocaine'

module OmfRc::Util::Iw
  include OmfRc::ResourceProxyDSL
  include Cocaine
  include Hashie

  utility :ip
  utility :wpa
  utility :hostapd

  # Parse iw help page and set up all configure methods available for iw command
  #
  begin
    CommandLine.new("iw", "help").run.chomp.gsub(/^\t/, '').split("\n").map {|v| v.match(/[phy|dev] <.+> set (\w+) .*/) && $1 }.compact.uniq.each do |p|
      next if p == 'type'
      configure p do |device, value|
        CommandLine.new("iw", "dev :dev set :property :value",
                        :dev => device.property.if_name,
                        :property => p,
                        :value => value).run
      end
    end
  rescue Cocaine::CommandNotFoundError
    logger.warn "Command iw not found"
  end

  # Parse iw link command output and return as a mash
  #
  request :link do |device|
    known_properties = Mash.new

    command = CommandLine.new("iw", "dev :dev link", :dev => device.property.if_name)

    command.run.chomp.gsub(/^\t/, '').split("\n").drop(1).each do |v|
      v.match(/^(.+):\W*(.+)$/).tap do |m|
        m && known_properties[m[1].downcase.gsub(/\W+/, '_')] = m[2].gsub(/^\W+/, '')
      end
    end

    known_properties
  end

  # Parse iw info command output and return as a mash
  #
  request :info do |device|
    known_properties = Mash.new

    command = CommandLine.new("iw", "dev :dev info", :dev => device.property.if_name)

    command.run.chomp.split("\n").drop(1).each do |v|
      v.match(/^\W*(.+) (.+)$/).tap do |m|
        m && known_properties[m[1].downcase.gsub(/\W+/, '_')] = m[2].gsub(/^\W+/, '')
      end
    end

    known_properties
  end

  # Delete current interface, clean up
  #
  work :delete_interface do |device|
    CommandLine.new("iw", "dev :dev del", :dev => device.property.if_name).run
  end

  # Add interface to device
  #
  work :add_interface do |device, type|
    CommandLine.new("iw", "phy :phy interface add :dev type :type",
                    :phy => device.property.phy,
                    :dev => device.property.if_name,
                    :type => type.to_s).run
  end

  # Set up or join a ibss network
  #
  work :join_ibss do |device|
    CommandLine.new("iw", "dev :device ibss join :essid :frequency",
                      :device => device.property.if_name.to_s,
                      :essid => device.property.essid.to_s,
                      :frequency => device.property.frequency.to_s).run
  end

  # Validate internal properties based on interface mode
  #
  work :validate_iw_properties do |device|
    raise ArgumentError, "Missing phyical device name" if device.property.phy.nil?

    unless %w(master managed adhoc monitor).include? device.property.mode
      raise ArgumentError, "Mode must be master, managed, adhoc, or monitor, got #{device.property.mode}"
    end

    case device.property.mode.to_sym
    when :master
      unless %w(a b g n).include? device.property.hw_mode
        raise ArgumentError, "Hardware mode must be a, b, g, or n, got #{device.property.hw_mode}"
      end
      %w(channel essid).each do |p|
        raise ArgumentError, "#{p} must not be nil" if device.property.send(p).nil?
      end
    when :managed
      %w(essid).each do |p|
        raise ArgumentError, "#{p} must not be nil" if device.property.send(p).nil?
      end
    when :adhoc
      %w(essid frequency).each do |p|
        raise ArgumentError, "#{p} must not be nil" if device.property.send(p).nil?
      end
    end
  end

  # Configure the interface with mode managed, master, adhoc or monitor
  #
  configure :mode do |device, value|
    # capture value hash and store internally
    device.property.update(value)

    if device.property.phy && device.property.phy =~ /^%(\d+)%$/
      wlan_phy_device = device.request_wlan_devices[$1.to_i]
      if wlan_phy_device
        device.property.phy = wlan_phy_device[:name]
      else
        raise ArgumentError, "Could not find your wifi device no #{$1.to_i}"
      end
    end

    device.validate_iw_properties

    device.delete_interface rescue logger.warn "Interface #{device.property.if_name} not found"

    # TODO should just remove all interfaces from physical device, at least make it optional

    case device.property.mode.to_sym
    when :master
      device.add_interface(:managed)
      device.hostapd
    when :managed
      device.add_interface(:managed)
      device.wpasup
    when :adhoc
      device.add_interface(:adhoc)
      device.interface_up
      device.join_ibss
    when :monitor
      device.add_interface(:monitor)
      device.interface_up
    end

    device.configure_ip_addr(device.property.ip_addr) if device.property.ip_addr
  end
end
