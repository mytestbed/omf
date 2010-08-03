 module OMF
  module Admin
    module Web     
      #
      # This class defines a Servlet (subclass of HTTPServlet::AbstractServlet) for experiment properties
      #
      class SetExpPropertyServlet < WEBrick::HTTPServlet::AbstractServlet
        #
        # Process an incoming HTTP 'GET' request
        #
        # - req = the full HTTP 'GET' request
        # - res = the HTTP reply to send back
        #
        def do_GET(req, res)
          q = req.query
          name = q['name']
          value = q['value']
          if (name == nil || value == nil)
            raise HTTPStatus::BadRequest, "Missing sargument 'name' or 'value'"
          end
          prop = Experiment.props[name]
          if (prop == nil)
            raise HTTPStatus::BadRequest, "Undefined property '#{name}'"
          end
          prop.set(value)
    
          res['ContentType'] = "text"
          res.body = "Done"
        end
      end
    end
  end
end

