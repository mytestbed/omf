require 'hashie'

module OmfRc::Util::Iw
  include OmfRc::ResourceProxyDSL

  OmfCommon::Command.execute("iw help").chomp.gsub(/^\t/, '').split("\n").map {|v| v.match(/[phy|dev] <.+> set (\w+) .*/) && $1 }.compact.uniq.each do |p|
    configure p do |resource, value|
      OmfCommon::Command.execute("iw #{resource.hrn} set #{p} #{value}")
    end
  end

  request :link do |resource|
    known_properties = Hashie::Mash.new

    OmfCommon::Command.execute("iw #{resource.hrn} link").chomp.gsub(/^\t/, '').split("\n").drop(1).each do |v|
      v.match(/^(.+):\W*(.+)$/).tap do |m|
        m && known_properties[m[1].downcase.gsub(/\W+/, '_')] = m[2].gsub(/^\W+/, '')
      end
    end

    known_properties
  end
end
