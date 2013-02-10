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

      def defApplication(uri,name,&block)
        # URI parameter was used by previous OMF5 EC, for now we
        # do nothing with it in OMF6
        def_application(name,&block)
      end

      def defGroup(name, *members, &block)
        group = OmfEc::Group.new(name)
        OmfEc.exp.groups << group

        members.each do |m|
          m_group = OmfEc.exp.groups.find { |v| v.name == m }
          if m_group
            group.members += m_group.members
          else
            group.members << m
          end
        end

        block.call(group) if block

        OmfCommon.comm.subscribe(group.id, create_if_non_existent: true) do |rg|
          unless rg.error?
            warn "What?"

            warn "Subscribed to #{rg.address}"

            members.each do |m|
              group.add_resource(m)
            end

            Experiment.instance.process_events

            #rg.on_message lambda {|m| m.operation == :inform && m.inform_type == 'CREATION_FAILED' && m.context_id.nil? } do |i|
            #  warn "RC reports failure: '#{i.read_content("reason")}'"
            #end

            #rg.on_message lambda {|m| m.operation == :inform && m.inform_type == 'STATUS' } do |i|
            rg.on_message do |i|
              warn i
            end
              #r = OmfEc.exp.state.find { |v| v[:uid] == i.read_property(:uid) }
              #unless r.nil?
              #  i.each_property { |p_k, p_v| r[p_k] = p_v }
              #end
          end
        end
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
