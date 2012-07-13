module OmfRc::Util::Mod
  include OmfRc::ResourceProxyDSL

  request :modules do
    OmfCommon::Command.execute('lsmod').split("\n").map do |v|
      v.match(/^(\w+).+$/) && $1
    end.compact.tap { |ary| ary.shift }
  end

  configure :load_module do |resource, value|
    OmfCommon::Command.execute("modprobe #{value}")
  end
end
