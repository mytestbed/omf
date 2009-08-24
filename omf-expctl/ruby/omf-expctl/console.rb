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

require 'omf-common/readline'

module OMF
  module ExperimentController
    class Console < MObject
      include Singleton
      
      def run()
        puts ">>> RUN"
        return if @thread
        puts ">>> RUN 2"
          Readline::completion_proc = Proc.new do |args|
            completion(args)
          end
        
        @thread = Thread.new do 
        puts ">>> RUN 2"
          Readline::completion_proc = Proc.new do |args|
            completion(args)
          end
        puts ">>> RUN 2"
          
          loop do
            begin
              puts "BEFORE"
              line = Readline::readline(prompt())
              puts "AFTER"              
              Readline::HISTORY.push(line)
              process(line)
              break unless @thread
            rescue Exception => ex
              error ex
            end
          end
        end
      end

      def stop()
        @thread = nil
      end
      
      def process(line)
        if line == 'quit' || line == 'exit'
          stop
          NodeHandler.exit
          return
        end
        puts "You typed: #{line}"
      end
    
      def completion(args)
        #puts "COMP #{args.inspect} (#{RbReadline.rl_copy_text 0, -1})"
        'foo'
      end
      
      def prompt()
        "> "
      end
    end
  end
end
