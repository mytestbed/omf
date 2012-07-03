module OmfRc::Util::Mod
  include OmfRc::ResourceProxyDSL

  register_utility :mod

  request :modules do
    OmfCommon::Command.execute('lsmod').split("\n").map do |v|
      v.match(/^(.+)\W*.+$/) && $1
    end.compact
  end

  configure :load_module do |resource, value|
    OmfCommon::Command.execute("modprobe #{value}")
  end
end
