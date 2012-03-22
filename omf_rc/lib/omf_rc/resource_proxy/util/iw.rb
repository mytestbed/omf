require 'hashie'
module OmfRc::ResourceProxy::Util::Iw

  IW_CMD = "iw"

  def configure_property(property, value)
    known_properties = OmfRc::Cmd.exec("#{IW_CMD} -h").chomp.gsub(/^\t/, '').split("\n").map {|v| v.match(/[phy|dev] <.+> set (\w+) .*/) && $1 }.compact.uniq

    if known_properties.include?(property.to_s)
      OmfRc::Cmd.exec("#{IW_CMD} #{uid} set #{property.to_s} #{value}")
    else
      super
    end
  end

  def request_property(property)
    known_properties = Hashie::Mash.new

    OmfRc::Cmd.exec("#{IW_CMD} #{uid} link").chomp.gsub(/^\t/, '').split("\n").drop(1).each do |v|
      v.match(/^(.+):\W*(.+)$/).tap do |m|
        m && known_properties[m[1].downcase.gsub(/\W+/, '_')] = m[2].gsub(/^\W+/, '')
      end
    end

    known_properties.send(property) || super
  end
end

