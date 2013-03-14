module OmfEc
  module Backward
    module DSL
      class << self
        def included(base)
          v5_style(:defProperty, base)
          v5_style(:defEvent, base)
          v5_style(:onEvent, base)
          v5_style(:allEqual, base)
          v5_style(:onEvent, base)
          v5_style(:allGroups, base)
          v5_style(:allNodes!, base)
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

      def defApplication(uri, name=nil ,&block)
        # URI parameter was used by previous OMF5 EC, for now we
        # do nothing with it in OMF6
        name = uri if name.nil?
        def_application(name,&block)
      end

      def defGroup(name, *members, &block)
        group = OmfEc::Group.new(name)
        OmfEc.experiment.add_group(group)
        group.add_resource(*members)

        block.call(group) if block
      end

      # Wait for some time before issuing more commands
      #
      # @param [Fixnum] duration Time to wait in seconds (can be
      #
      def wait(duration)
        info "Request from Experiment Script: Wait for #{duration}s...."
        warn "Calling 'wait' or 'sleep' will block entire EC event loop. Please try 'after' or 'every'"
        sleep duration
      end
    end
  end
end
