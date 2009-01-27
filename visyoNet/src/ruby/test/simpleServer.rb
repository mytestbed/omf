require 'webrick'
require 'webrick/httpservlet/erbhandler'
require 'singleton'
require 'util/mobject'

include WEBrick

@httpServer = HTTPServer.new(:Port => 8080, :DocumentRoot => "../public")

@httpServer.mount_proc("" + "/model") { |req, res|
  session = getSession(req)
  res.body = session.getVisModel.to_XML
  res['content-type'] = 'text/xml'
}

      
# use INT and TERM signals to shutdown
['INT', 'TERM'].each { |signal|
  trap(signal){ 
    @httpServer.shutdown 
  }
}
      
@httpServer.start
