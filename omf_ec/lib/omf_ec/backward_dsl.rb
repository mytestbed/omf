module OmfEc
  module BackwardDSL
    class << self
      def included(base)
        v5_style(:defGroup, base)
        v5_style(:defProperty, base)
        v5_style(:defEvent, base)
        v5_style(:onEvent, base)
        v5_style(:allEqual, base)
        v5_style(:onEvent, base)
        v5_style(:allGroups, base)
      end

      def v5_style(name, base)
        new_name = name.to_s.underscore.to_sym
        unless method_defined? new_name
          base.class_eval do
            alias_method name, new_name
          end
        end
      end
    end
  end
end
