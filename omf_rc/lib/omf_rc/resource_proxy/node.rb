module OmfRc::ResourceProxy::Node
  include OmfRc::ResourceProxyDSL

  register_proxy :node

  utility :mod

  request :proxies do
    OmfRc::ResourceFactory.proxy_list
  end

  request :interfaces do |node|
    node.children.find_all { |v| v.type == 'net' || v.type == 'wlan' }.map do |v|
      { name: v.hrn, type: v.type, uid: v.uid }
    end.sort { |x, y| x[:name] <=> y[:name] }
  end

  request :applications do |node|
    node.children.find_all { |v| v.type =~ /application/ }.map do |v|
      { name: v.hrn, type: v.type, uid: v.uid }
    end.sort { |x, y| x[:name] <=> y[:name] }
  end

  request :devices do |resource|
    devices = []
    # Support net devices for now
    category = "net"

    Dir.glob("/sys/class/net/eth*").each do |v|
      File.exist?("#{v}/uevent") && File.open("#{v}/uevent") do |f|
        subcategory = f.read.match(/DEVTYPE=(.+)/) && $1
        proxy = "net"
        File.exist?("#{v}/device/uevent") && File.open("#{v}/device/uevent") do |f|
          driver = f.read.match(/DRIVER=(.+)/) && $1
          device = { name: File.basename(v), driver: driver, category: category }
          device[:subcategory] = subcategory if subcategory
          device[:proxy] = proxy if resource.request_proxies.include?(proxy.to_sym)
          devices << device
        end
      end
    end

    Dir.glob("/sys/class/ieee80211/*").each do |v|
      subcategory = "wlan"
      proxy = "wlan"
      File.exist?("#{v}/device/uevent") && File.open("#{v}/device/uevent") do |f|
        driver = f.read.match(/DRIVER=(.+)/) && $1
        device = { name: File.basename(v), driver: driver, category: category, subcategory: subcategory }
        device[:proxy] = proxy if resource.request_proxies.include?(proxy.to_sym)
        devices << device
      end
    end
    devices
  end
end
