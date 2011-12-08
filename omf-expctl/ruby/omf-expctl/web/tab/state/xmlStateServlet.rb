module OMF
  module EC
    module Web
      module State
        VIEW = :state
        
        def self.configure(server, options = {})
          server.mount("/xml", XMLStateServlet)
          server.mount("/xpath", XPathServlet)
          
          server.mount('/state/show', ViewServlet, options)
          server.addTab(VIEW, "/state/show", :name => 'State',
              :title => "Display current state of experiment")
          
        end
      
        def self.stateAsXML(xslt = nil, xpath = nil)
          ss = StringIO.new()
          ss.write("<?xml version='1.0'?>\n")
      
          if (xslt)
            ss.write("<?xml-stylesheet href='#{xslt}' type='text/xsl'?>")
          end
      
          if (xpath == nil)
            #NodeHandler::DOCUMENT.write(ss, 2, true, true)
            NodeHandler::DOCUMENT.write(ss, 2)
          else
            ss.write("<match>\n")
            match = REXML::XPath.match(NodeHandler::DOCUMENT, xpath)
            match.each { |frag|
              frag.write(ss, 2)
            }
            ss.write("</match>\n")
          end
          ss.string
        end
      
#
        # This class defines a XML Servlet (subclass of HTTPServlet::AbstractServlet)
        #
        class XMLStateServlet < WEBrick::HTTPServlet::AbstractServlet
          #
          # Process an incoming HTTP 'GET' request
          #
          # - req = the full HTTP 'GET' request
          # - res = the HTTP reply to send back
          #
          def do_GET(req, res)
            res['Content-Type'] = "text/xml"
            xslt = req.query['xslt']
            xpath = req.query['xpath']

            res.body = State::stateAsXML(xslt, xpath)
          end
        end

        #
        # This class defines a XPath Servlet (subclass of HTTPServlet::AbstractServlet)
        #
        class XPathServlet < WEBrick::HTTPServlet::AbstractServlet
          #
          # Process an incoming HTTP 'GET' request
          #
          # - req = the full HTTP 'GET' request
          # - res = the HTTP reply to send back
          #
          def do_GET(req, res)
            q = req.query['q']
            unless q
              raise "Missing parameter 'q'"
            end
            filter = req.query['f']
      
            res['ContentType'] = "text/xml"
            ss = StringIO.new()
            ss.write("<?xml version='1.0'?>\n")
            ss.write("<match>\n")
            match = REXML::XPath.match(NodeHandler::DOCUMENT, q)
            #match.write(ss, 2, true, true)
            if (filter == nil)
              match.each { |frag|
                ss.write("<p>\n")
                frag.write(ss, 2)
                ss.write("</p>\n")
              }
            else
              # issue filter against all matches
              match.each { |m|
                match2 = REXML::XPath.match(m, filter)
                ss.write("<p>\n")
                match2.each { |frag|
                  ss.write("<f>\n")
                  frag.write(ss, 2)
                  ss.write("</f>\n")
                }
                ss.write("</p>\n")
              }
            end
            ss.write("</match>\n")
            res.body = ss.string
          end
        end
        
        class ViewServlet < WEBrick::HTTPServlet::AbstractServlet

          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = VIEW
            
            opts[:state] = {
              :content => State::stateAsXML,
              :mime => 'text/xml'
            }
            res.body = MabRenderer.render('show', opts, ViewHelper)
          end
        end

          
      end
    end
  end
end

