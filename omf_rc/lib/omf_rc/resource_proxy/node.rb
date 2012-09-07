module OmfRc::ResourceProxy::Node
  include OmfRc::ResourceProxyDSL

  register_proxy :node

  hook :before_ready do |resource|
    logger.info "#{resource.uid} is now ready"
  end

  hook :before_release do |resource|
    logger.info "#{resource.uid} is now released"
  end

  request :proxies do
    OmfRc::ResourceFactory.proxy_list
  end

  request :devices do |resource|
    devices = []
    sys_path = "/sys/class"
    Dir.chdir(sys_path) do
      Dir.glob("net").find_all { |v| File.directory?(v) }.each do |v|
        category = File.basename(v)
        Dir.glob("#{category}/*").each do |v|
          File.exist?("#{v}/uevent") && File.open("#{v}/uevent") do |f|
            subcategory = f.read.match(/DEVTYPE=(.+)/) && $1
            proxy = subcategory || category
            File.exist?("#{v}/device/uevent") && File.open("#{v}/device/uevent") do |f|
              driver = f.read.match(/DRIVER=(.+)/) && $1
              devices << {
                name: File.basename(v),
                driver: driver,
                category: category,
                subcategory: subcategory,
                proxy: (proxy if resource.request_proxies.include?(proxy)) }
            end
          end
        end
      end
    end
    devices
  end
end
