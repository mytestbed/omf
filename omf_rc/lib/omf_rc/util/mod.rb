require 'hashie'
require 'cocaine'

module OmfRc::Util::Mod
  include OmfRc::ResourceProxyDSL
  include Cocaine
  include Hashie

  request :modules do
    CommandLine.new('lsmod').run.split("\n").map do |v|
      v.match(/^(\w+).+$/) && $1
    end.compact.tap { |ary| ary.shift }
  end

  configure :load_module do |resource, value|
    raise ArgumentError, "Please provide at least module name" if value.name.nil?

    flags_string = nil

    if !value.flags.nil?
      if value.flags.kind_of?(Hash)
        flags_string = value.flags.keys.map do |k|
          "--#{k} #{value.flags[k]}"
        end.join(" ")
      else
        raise ArgumentError, "Please provide modprobe flags as a hash"
      end
    end

    if value.unload
      CommandLine.new("modprobe", "-r :mod_names", :mod_names => [value.unload].flatten.join(' ')).run
    end

    CommandLine.new("modprobe", ":flags :mod_name :module_parameters",
                    :mod_name => value.name.to_s,
                    :flags => flags_string,
                    :module_parameters => value.mod_params.to_s).run

    "#{value.name} loaded"
  end
end
