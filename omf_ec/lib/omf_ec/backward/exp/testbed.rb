def create_app(testbed)
  testbed.create(:application) do |reply|
    if reply.success?
      app = reply.resource

      app.on_subscribed do
        app.request([:platform])

        after(1) { app.configure(binary_path: @cmd) }
        after(2) { app.configure(state: :running) }

        app.on_status  do |m|
          case m.itype
          when 'STATUS'
            if m[:status_type] == 'APP_EVENT'
              after(2) { OmfCommon.comm.disconnect } if m[:event] =~ /DONE.(OK|ERROR)/
                info m[:msg]
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
