#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
require 'omf-expctl/nodeHandler'

startTime = Time.now
cleanExit = false

# Initialize the state tracking, Parse the command line options, and run the EC
begin
  puts ""
  TraceState.init()
  NodeHandler.instance.parseOptions(ARGV)
  NodeHandler.instance.run(self)
  cleanExit = true

# Process the various Exceptions...
rescue SystemExit
rescue Interrupt
  # ignore
rescue OEDLException => ex 
  begin
    bt = ex.backtrace 
    MObject.fatal('run', "----------")
    MObject.fatal('run', "  A fatal error was encountered while processing your"+
                         " experiment description.")
    MObject.fatal('run', "  Exception: #{ex.class}")
    MObject.fatal('run', "  Exception: #{ex}")
    MObject.fatal('run', "  In file: #{bt[0]}")
    MObject.fatal('run', "----------")
    MObject.debug('run', "\n\nTrace:\n\t#{bt.join("\n\t")}\n")
  rescue Exception
  end
rescue ServiceException => sex
  begin
    MObject.fatal('run', "Failed to call an Aggregate Manager Service")
    MObject.fatal('run', "Exception: #{sex.message} : #{sex.response.body}")
  rescue Exception
  end
rescue Exception => ex
  begin
    bt = ex.backtrace.join("\n\t")
    MObject.fatal('run', "----------")
    MObject.fatal('run', "  A fatal error was encountered while running your"+
                         " experiment.")
    MObject.fatal('run', "  Exception: #{ex.class}")
    MObject.fatal('run', "  Exception: #{ex}")
    MObject.fatal('run', "  For more information (e.g. trace) see the log "+
                         "file: /tmp/#{Experiment.ID}.log")
    MObject.fatal('run', "  (or see EC's config files to find the log's "+
                         "location)")
    MObject.debug('run', "\n\nTrace:\n\t#{bt}\n")
    MObject.fatal('run', "----------")
  rescue Exception
  end
end

# If EC is called in 'interactive' mode, then start a Ruby interpreter
#if NodeHandler.instance.interactive?
#  require 'omf-expctl/console'
#  
#  OMF::ExperimentController::Console.instance.run
##  require 'irb'
##  ARGV.clear
##  ARGV << "--simple-prompt"
##  ARGV << "--noinspect"
##  IRB.start()
#end

# End of the experimentation, Shutdown the EC
if (NodeHandler.instance.running?)
  NodeHandler.instance.shutdown
  duration = (Time.now - startTime).to_i
  MObject.info('run', "Experiment #{Experiment.ID} finished after #{duration / 60}:#{duration % 60}\n")
end

