module OmfEc
  module Backward
    module DefaultEvents

      class << self
        def included(base)
          base.instance_eval do

            def_event :ALL_UP do |state|
              all_groups? do |g|
                plan = g.members.uniq.sort
                actual = state.find_all do |v|
                  v[:membership] && v[:membership].include?(g.id)
                end.map { |v| v[:uid] }.sort
                plan == actual
              end
            end

            on_event :ALL_UP do
              all_groups do |group|
                # Deal with brilliant net.w0.ip syntax...
                group.net_ifs && group.net_ifs.each do |nif|
                  nif.map_channel_freq
                  r_type = nif.conf[:type]
                  r_hrn = nif.conf[:hrn]
                  r_index = nif.conf[:index]

                  conf_to_send =
                    if r_type == 'wlan'
                      { type: r_type,
                        mode: nif.conf.merge(:phy => "<%= request_wlan_devices[#{r_index}][:name] %>").except(:hrn, :type, :index)
                      }
                    else
                      nif.conf.merge(type: r_type).except(:index)
                    end

                  group.create_resource(r_hrn, conf_to_send)
                end
                # Create proxies for each apps that were added to this group
                group.app_contexts.each { |a| group.create_resource(a.name, a.properties) }
              end
            end

            def_event :ALL_INTERFACE_UP do |state|
              all_groups? do |g|
                plan = g.net_ifs.map { |v| v.conf[:hrn] }.uniq.size * g.members.uniq.size
                actual = state.find_all do |v|
                  v[:membership] &&
                    (v[:membership].include?("#{g.id}_wlan") || v[:membership].include?("#{g.id}_net"))
                end.size
                plan == actual
              end
            end

            def_event :ALL_UP_AND_INSTALLED do |state|
              all_groups? do |g|
                plan = g.app_contexts.size * g.members.uniq.size
                actual = state.find_all do |v|
                  v[:membership] && v[:membership].include?("#{g.id}_application")
                end.size
                plan == actual
              end
            end

          end
        end
      end

    end
  end
end
