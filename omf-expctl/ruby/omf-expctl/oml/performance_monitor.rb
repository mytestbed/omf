#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
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
# = performance_monitor.rb
#
# == Description
#
# This file contains support for monitoring the performance of the EC.
#

require 'omf-common/mobject'

# OML4R should be provided in its own GEM - fix the following if that happens
#require 'oml4r'
require 'omf-expctl/oml/oml4r'

module OMF; module EC; module OML; end end end

module OMF::EC::OML 

  class PerformanceMonitor < MObject


    def self.report_status(label, message = nil)
      TestbedStatsMP.inject Experiment.ID, label, message || '-'
    end

    def self.start()
      use_oml = false
      if omlURL = OConfig[:ec_config][:omluri]
        use_oml = true
        OML4R::Stream.create(:default, omlURL)
	
	# Send the Stats messages to a system (domain) wide database
	domain = OConfig[:ec_config][:domain]
	TestbedStatsMP.stream :default, "system_#{domain}"
      end
      if use_oml
        OML4R::init [], :domain => Experiment.ID,
                        :nodeID => "console",
                        :appID => "ec_ctl"
      end
    end

  end

  # Define a testbed wide MP for gasthering overall statistics
  class TestbedStatsMP < OML4R::MPBase
    name :stats
#    stream :default, :system

    param :exp_id
    param :label
    param :message
  end


end # OMF::EC::OML
