
require 'omf-common/mobject'
require 'omf-web/tabbed_server'
require 'omf-web/widget/code'
require 'omf-web/widget/log/log_outputter'

MObject.initLog('test', 'test', :configFile => "#{File.dirname(__FILE__)}/log_config.xml")

# Move one node
i = 0
Thread.new do
  begin
    loop do
      sleep 5
      MObject.error(:cat, "This is error #{i}")
      MObject.warn(:cat, "This is warning #{i}")
      MObject.info(:cat, "This is inf #{i}")
      MObject.debug(:cat, "This is debug #{i}")
      i += 1
    end
  rescue Exception => ex
    puts ex
    puts ex.backtrace.join("\n")
  end
end

# Configure the web server
#
opts = {
  :page_title => 'Log Tab Demo',
  :use_tabs => [:log]
}
OMF::Web.start(opts)
