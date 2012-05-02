module OmfRc
  module ResourceProxy
    module Node
      def request_property(property)
        case property
        when /^devices$/
          OmfRc::Cmd.exec("lspci").split("\n").map do |v|
            v.match(/^.{2}:.{2}\.. (.+): (.+)$/) && { type: $1, name: $2 }
          end +
          OmfRc::Cmd.exec("lsusb").split("\n").map do |v|
            v.match(/.{4}:.{4} (.+)$/) && { type: 'USB', name: $1 }
          end
        else
          super
        end
      end

      def configure_property(property, value)
        # TODO what could configure a node,
        super
      end
    end
  end
end
