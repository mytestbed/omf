# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

def create_app(testbed)
  testbed.create(:application, binary_path: @cmd) do |reply|
    if reply.success?
      app = reply.resource

      app.on_subscribed do
        app.configure(state: :running)

        app.on_inform  do |m|
          case m.itype
          when 'STATUS'
            if m[:status_type] == 'APP_EVENT'
              after(2) { OmfCommon.comm.disconnect } if m[:event] =~ /EXIT/
              info m[:msg] if m[:msg]
            else
              m.each_property do |k, v|
                info "#{k} => #{v.strip}" unless v.nil?
              end
            end
          when 'WARN'
            warn m[:reason]
          when 'ERROR'
            error m[:reason]
          end
        end
      end
    else
      error reply[:reason]
    end
  end
end

OmfCommon.comm.subscribe('testbed') do |testbed|
  unless testbed.error?
    create_app(testbed)
  else
    error testbed.inspect
  end
end
