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
# = mstream.rb
#
# == Description
#
# This class describes a measurement stream created by an OML'ified application
# or collection service
#

module OMF
  module ExperimentController
    module OML

      class MStream < MObject
        @@instances = {}
        
        def self.[](uri)
          @@instances[uri] || self.find(uri)
        end

        def self.find(uri)
          @@instances[uri] || self.new(uri)
        end
      
        def self.omlConfig(mstreams)
          cfg = []
          mstreams.each do |ms|
            cfg << ms.omlConfig
          end
          cfg
        end
        
        def initialize(mDef, application, &block)
          @mdef = mDef
          @application = application
          
          block.call(self) if block
        end
        
        def omlConfig()
          puts @mdef
        end

        
        def SERVER_TIMESTAMP()
          'oml_ts_server'  # should be more descriptive
        end

      end # MStream
    
    end # module OML
  end # module ExperimentController
end # OMF
