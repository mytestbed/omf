#
# Copyright (c) 2009 National ICT Australia (NICTA), Australia
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
# = console.rb
#
# == Description
#
# This class provides an console to interact with a running experiment.
#


require 'irb'
require 'irb/completion'
require 'rawline'

module OMF
  module ExperimentController
    module Console
      
      def self.start()
        #IrbConsole.instance.start()  
        SimpleConsole.instance.start()  
      end
      
      class SimpleConsole
        include Singleton
  
        def start()
          return if @thread
          
          @thread = Thread.new do 
            _run
            NodeHandler.exit()
          end        
        end
        
        def _run()
          require 'readline'
          #puts "111"
          binding = OMF::ExperimentController::CmdContext.instance._binding()
          while (@thread) do
            #puts "222"
            line = Readline::readline('> ')
            Readline::HISTORY.push(line)
            begin                    
              res = eval(line, binding, __FILE__, __LINE__).inspect
              if (res)
                puts res # >>>>>>>>>>> <#{line}> <#{x}>"
              end
            rescue Exception => ex
              puts "EXCEPTION: #{ex}"
            end
          end        
        end      
        
        
        
      end
      
      class RawlineInputMethod < IRB::ReadlineInputMethod
        include Rawline
        
        def gets
          if l = readline(@prompt, false)
            HISTORY.push(l) if !l.empty?
            @line[@line_no += 1] = l + "\n"
          else
            @eof = true
            l
          end
        end
      end
  
      class Workspace #< IRB::WorkSpace
        attr_reader :main
        
        def initialize(*args)
          @binding = OMF::ExperimentController::CmdContext.instance._binding()
          @main = eval("self", @binding)          
        end
        
        def evaluate(context, statements, file = __FILE__, line = __LINE__)
          x = eval(statements, @binding, file, line)
          #puts ">>>>>>>>>>> <#{statements}> <#{x}>"
          x
        end
        
        # error message manipulator
        def filter_backtrace(bt)
          return nil if bt =~ /irb\/.*\.rb/
          bt.sub!(/:\s*in `_binding'/){""}
          bt.sub!(/from\s*omf-expctl\/console\.rb.*/){""}
          bt
        end
        
        
        def method_missing(method, *args, &block)
          error "Missing method: #{method} <#{args.join('#')}> <#{args.collect do |a| a.class.to_s end.join('#')}>"
        end
        
  
      end
      
      class IrbConsole
        include Singleton
  
        def start()
          return if @thread
          
          Rawline.basic_word_break_characters= " \t\n\"\\'`><;|&{(" 
          Rawline.completion_append_character = nil
          Rawline.completion_proc = IRB::InputCompletor::CompletionProc
          
          @thread = Thread.new do 
            run_irb
            NodeHandler.exit()
          end        
        end
        
        def run_irb()
          begin                    
            ARGV.clear
            IRB.setup(nil)

            # Prompts
            IRB.conf[:PROMPT][:CUSTOM] = {
                :PROMPT_N => "> ",
                :PROMPT_I => "> ",
                :PROMPT_S => nil,
                :PROMPT_C => "> ",
                :RETURN => ""
            }
            IRB.conf[:PROMPT_MODE] = :CUSTOM

            irb = IRB::Irb.new(Workspace.new, RawlineInputMethod.new, nil)
            IRB.conf[:MAIN_CONTEXT] = irb.context
            
            catch(:IRB_EXIT) do
              irb.eval_input
            end

          rescue Exception => ex
            puts "EXCEPTION: #{ex}"
          end
    
#          trap("SIGINT") do
#            irb.signal_handle
#          end
        end      
      end
    end # Console
  end # ExperimentController
end # OMF

## Monkey patch IRB
#module IRB
#  @CONF[:SCRIPT] = RawlineInputMethod.new
#end
    
    
#module OMF
#  module ExperimentController
#    class Console2 < MObject
#      include Singleton
#      
#      def run()
#        require 'omf-common/readline'
#
#        puts ">>> RUN"
#        return if @thread
#        puts ">>> RUN 2"
#          Readline::completion_proc = Proc.new do |args|
#            completion(args)
#          end
#        
#        @thread = Thread.new do 
#        puts ">>> RUN 2"
#          Readline::completion_proc = Proc.new do |args|
#            completion(args)
#          end
#        puts ">>> RUN 2"
#          
#          loop do
#            begin
#              puts "BEFORE"
#              line = Readline::readline(prompt())
#              puts "AFTER"              
#              Readline::HISTORY.push(line)
#              process(line)
#              break unless @thread
#            rescue Exception => ex
#              error ex
#            end
#          end
#        end
#      end
#
#      def stop()
#        @thread = nil
#      end
#      
#      def process(line)
#        if line == 'quit' || line == 'exit'
#          stop
#          NodeHandler.exit
#          return
#        end
#        puts "You typed: #{line}"
#      end
#    
#      def completion(args)
#        #puts "COMP #{args.inspect} (#{RbReadline.rl_copy_text 0, -1})"
#        'foo'
#      end
#      
#      def prompt()
#        "> "
#      end
#    end
#  end
#end
