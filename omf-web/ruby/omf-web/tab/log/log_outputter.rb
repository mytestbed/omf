require 'rubygems'
require 'log4r/outputter/outputter'
require 'log4r/formatter/formatter'


module OMF::Web::Tab::Log
  class LogOutputter < Log4r::Outputter
    @@instance = nil
    
    def self.instance
      @@instance
    end
    
    def initialize(name = 'remote', hash={})
      super(name, hash)
      self.formatter = (hash[:formatter] or hash['formatter'] or WebFormatter.new)

      @event = []
      @@instance = self
    end
    
    def remaining_events(index)
      @event[index .. -1]
    end
  
    def format(logevent)
      # @formatter is guaranteed to be DefaultFormatter if no Formatter
      # was specified
      @event << [@formatter.format(logevent), logevent]
      #puts ">>>>>>>>>>>>>>>> #{logevent.inspect}"
    end

  end # LogOutputter
  
  class WebFormatter < Log4r::BasicFormatter

    def format(event)
      lname = Log4r::LNAMES[event.level]
      fs = "<tr class=\"log_#{lname.downcase}\"><td class='%s'>%s</td><td class='name'>%s"
      buff = sprintf(fs, lname.downcase, lname, event.name)
      buff += (event.tracer.nil? ? "" : "(#{event.tracer[0]})") + ":</td>"
      data = format_object(event.data).gsub(/</, '&lt;')
      buff += sprintf("<td class='data'>%*s</td></tr>", Log4r::MaxLevelLength, data)
      buff
    end

  end # WebFormatter

end # module
  