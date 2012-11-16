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

      # Place holder for defApplication magic
      def defApplication
      end

      def defGroup(name, *members, &block)
        OmfEc.comm.subscribe(name, create_if_non_existent: true) do |m|
          unless m.error?
            group = OmfEc::Group.new(name)
            OmfEc.exp.groups << group

            members.each do |m|
              group.add_resource(m)
            end

            if block && !members.empty?
              def_event "all_joined_to_#{name}".to_sym do |state|
                state.find_all do |v|
                  members.include?(v[:uid]) &&
                    (v[:membership] && v[:membership].include?(name))
                end.size >= members.size
              end

              on_event "all_joined_to_#{name}".to_sym do
                block.call group

                # Deal with brilliant net.w0.ip syntax...
                group.net_ifs && group.net_ifs.each do |nif|
                  nif.map_channel_freq
                  r_type = nif.conf.delete(:type)
                  r_hrn = nif.conf.delete(:hrn)

                  # FIXME using 'after' here is just hopeless
                  after 2.seconds do
                    group.create_resource(r_hrn, :type => r_type)

                    after 2.seconds do
                      group.resources[:type => r_type].mode = nif.conf.merge(:phy => "phy#{nif.conf.delete(:index)}")
                    end

                    after 4.seconds do
                      r_ip_addr = nif.conf.delete(:ip_addr)
                      group.resources[:type => r_type].ip_addr = r_ip_addr if r_ip_addr
                    end
                  end
                end
              end
            end
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
