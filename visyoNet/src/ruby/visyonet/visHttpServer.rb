require "visyonet/visFlashServer"
require "visyonet/context"
require "socket"
require 'webrick'
require 'webrick/httpservlet/erbhandler'
require 'singleton'
require 'util/mobject'
require 'svg/svg'

include WEBrick

# this module represents the interface to the visualization server

module VisyoNet

  class UpdateAvgIntServlet < HTTPServlet::AbstractServlet
    def do_GET(req, res)
      newVal = req.query['val']
      if(newVal != nil) 
        puts "UpdateAvgIntervalServlet: reques[val] = " + newVal
        
        queryManager = VisSession.instance(req).queryManager
        if (queryManager)
          queryManager.setAveragingInterval(newVal.to_i)
        end
        res.status = 204   # no response to send - the browser should not reload current page
      end
    end
  end
#session.getVisModel.to_XML
  
  class UpdateAvgIntServlet < HTTPServlet::AbstractServlet
    def do_GET(req, res)
      newVal = req.query['val']
      if(newVal != nil) 
        puts "UpdateAvgIntervalServlet: reques[val] = " + newVal
        
        queryManager = VisSession.instance(req).queryManager
        if (queryManager)
          queryManager.setAveragingInterval(newVal.to_i)
        end
        res.status = 204   # no response to send - the browser should not reload current page
      end
    end
  end
  
  
  class LoadConfigFiles < HTTPServlet::AbstractServlet
    def do_POST(req, res)
      newDBConfig = req.query['DBConfigFile']
      newVisMappingConfig = req.query['VisMappingConfigFile']
      
      session = VisSession.instance(req)
      if (newDBConfig)
        session.queryManager.loadConfig(newDBConfig)
      end
      if (newVisMappingConfig)
        session.visModel.loadConfig(newVisMappingConfig)
      end
      res.body = "OK"
    end
  end
  
  
  class VisHttpServer < MObject
    include Singleton 
    
    def processConfig(root)
      if @initialized 
        raise 'VisHttpServer already initialized'
      end
      
      if (root.name != 'HttpServer')
        MObject.error('processConfig', 
        "Doesn't appear to be a proper HttpServer config - starts with '#{root.name}'")
        return false
      end
      @updatePort = 99
      @httpPort = 80
      @docRoot = ""
      root.elements.each { |el|
        case el.name
        when 'UpdatePort'
          @updatePort = el.text.to_i
        when 'HTTPPort'
          @httpPort = el.text.to_i
        when 'HTTPDocRoot'
          @docRoot = el.text
        else
          error("Unknown config tag '#{el.name}'")
        end
      }
      if (! File.directory?(@docRoot))
        raise "doc root '#{@docRoot}' is not a directory"
      end
      @initialized = true
    end
    
    # Return the session object. If none exists, 
    # create a new one
    # 
    def getSession(req)
      # right now we only have one session
      if (@session == nil)
        @session = VisSession.new(Context['/aruba'])
      end
      @session
    end
    
    # Return the context object. 
    # 
    def getContext(req)
      path = req.path
      debug(path)
      return Context[path]
    end
    
    def initialize()
      @httpServer = nil
      @visServer = nil
      @initialized = false
    end
    
    
    # use this method to start the visualization server
    
    def start()  
      if (!@initialized)
        raise 'VisHttpServer not initialized yet'
      end
      
      if (@httpServer != nil)
        # already running
        return
      end
      
      # start the VisServer first - this will open the listening socket
      @visServer = VisServer.new(@updatePort)
      @visServer.run()
      
      # start the HTTP server
      
      @httpServer = HTTPServer.new(:Port => @httpPort, :DocumentRoot => @docRoot)
      
      # mount different handlers     
      @httpServer.mount("/visyonet/updateInterval", UpdateAvgIntServlet)
      @httpServer.mount("/visyonet/loadConfig", LoadConfigFiles)
      @httpServer.mount_proc("/svg") { |req, res| 
        svg = SVG.new('4in', '4in', '0 0 400 400')
        svg.scripts << SVG::ECMAScript.new(<<-END_OF_SOURCE)
            function myHover(filterName, opavalue) {
                var filterOj  = document.getElementById('a1');
                var opacityOj = document.getElementById('t1');
                opacityOj.setAttribute("style", "opacity:" + opavalue);
        //      filterOj.setAttribute("filter", "url(#" + filterName + ")")
            }
        END_OF_SOURCE
        
        svg << anc = SVG::Anchor.new('http://ruby-svg.sourceforge.jp/')
        
        anc << SVG::Ellipse.new(90, 50, 30, 15) {
          self.id    = "a1"
          self.style = SVG::Style.new(:fill => 'none', :stroke => 'magenta', :stroke_width => '8')
          self.attr  = %|onmouseover="myHover('filter1', 1)" onmouseout="myHover('', 0.5)"|
        }
        
        anc << SVG::Text.new(65, 55, "Ruby/SVG") {
          self.id    = "t1"
          self.style = SVG::Style.new(:opacity => '0.5')
          self.attr  = %|onmouseover="myHover('filter1', 1)" onmouseout="myHover('', 0.5)"|
        }
        res.body = svg.to_s
        res['Content-Type'] = "image/svg+xml"
      }
      Context.each {|context|
        debug("Mounting #{context.path}")
        file = @docRoot + '/visyonet/visyonet.html'
        @httpServer.mount(context.path, HTTPServlet::ERBHandler, file)
#        @httpServer.mount_proc(context.path) { |req, res|
#          file = @docRoot + req.path
#          puts ">>>>> '#{req.path}':#{File.exists?(file)}"
#          res.body = open(file){|io| io.read }
#        }
        @httpServer.mount_proc(context.path + "/model") { |req, res|
          begin
            session = getSession(req)
            #res.body = session.getVisModel.to_XML
            res.body = session.getVisModel.to_s
            res['content-type'] = 'text/xml'
          rescue Exception => ex
            bt = ex.backtrace.join("\n\t")
            warn("Exception: #{ex} (#{ex.class})\n\t#{bt}")
            raise ex
          end
        }
      }
      
      # use INT and TERM signals to shutdown
      ['INT', 'TERM'].each { |signal|
        trap(signal){ 
          @httpServer.shutdown 
          @visServer.stop()
        }
      }
      
      @httpServer.start
    end
    
  end
end # module