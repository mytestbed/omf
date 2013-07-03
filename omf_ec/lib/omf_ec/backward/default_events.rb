# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfEc
  module Backward
    module DefaultEvents

      class << self
        def included(base)
          base.instance_eval do

            def_event :ALL_UP do |state|
              all_groups? do |g|
                plan = g.members.uniq.sort
                actual = state.find_all { |v| v.joined?(g.address) }.map { |v| v[:address] }.sort

                debug "Planned: #{g.name}(#{g.address}): #{plan}"
                debug "Actual: #{g.name}(#{g.address}): #{actual}"

                plan.empty? ? false : plan == actual
              end
            end

            on_event :ALL_UP do
              all_groups do |group|
                # Deal with brilliant net.w0.ip syntax...
                group.net_ifs && group.net_ifs.each do |nif|
                  nif.map_channel_freq
                  r_type = nif.conf[:type]
                  r_if_name = nif.conf[:if_name]
                  r_index = nif.conf[:index]

                  conf_to_send =
                    if r_type == 'wlan'
                      { type: r_type,
                        if_name: r_if_name,
                        mode: nif.conf.merge(:phy => "%#{r_index}%").except(:if_name, :type, :index)
                      }
                    else
                      nif.conf.merge(type: r_type).except(:index)
                    end

                  group.create_resource(r_if_name, conf_to_send)
                end
                # Create proxies for each apps that were added to this group
                group.app_contexts.each { |a| group.create_resource(a.name, a.properties) }
              end
            end

            def_event :ALL_INTERFACE_UP do |state|
              all_groups? do |g|
                plan = g.net_ifs.map { |v| v.conf[:if_name] }.uniq.size * g.members.uniq.size
                actual = state.count { |v| v.joined?(g.address("wlan"), g.address("net")) }
                plan == actual
              end
            end

            def_event :ALL_UP_AND_INSTALLED do |state|
              all_groups? do |g|
                plan = g.app_contexts.size * g.members.uniq.size
                actual = state.count { |v| v.joined?(g.address("application")) }
                plan == actual
              end
            end

            def_event :ALL_APPS_DONE do |state|
              all_groups? do |g|
                plan = (g.execs.size + g.app_contexts.size) * g.members.uniq.size
                actual = state.count { |v| v.joined?(g.address("application")) && v[:event] == 'EXIT' }
                plan == 0 ? false : plan == actual
              end
            end

          end
        end
      end

    end
  end
end
