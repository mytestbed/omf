module OmfRc
  module ResourceProxy
    module App
      APPINFO = 'dpkg -l'
      def request_property(property)
        case property
        when /^version$/
          `#{APPINFO} #{uid} | awk 'END { print $3 }'`.match(/^[\d|\.|-]+$/) && $&
        else
          super
        end
      end

      def configure_property(property, value)
      end
    end
  end
end
