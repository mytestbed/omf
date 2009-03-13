#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 WINLAB, Rutgers University, USA
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
# = saveNode.rb
#
# == Description
#
# This file describes the Experiment that is used to save the disk image of a node within OMF.
# (In OMF, saving the disk image of a node is treated as an 'experiment' itself)
#
#
Experiment.name = "imageNode"
Experiment.project = "Orbit::Admin"

defProperty('node', [1, 1], "Node to save image of")
defProperty('pxe', '1.1.6', "PXE version to use")
defProperty('domain', '', "Domain of the node to save")
defProperty('started', 'false', "internal flag")

#
# Define nodes used in experiment
#
defGroup('save', Experiment.property('node')) {|n|
  n.pxeImage("#{prop.domain.value}", setPXE=true)
  #n.onNodeUp {|n|
  #  n.saveImage
  #}
}

everyNS('save', 10) { |ns|
  notDone = true
  ns.eachNode { |n|
    status = n.match('apps/*/status/')[0].to_s
    if status =~ /DONE/
      notDone = false
      if status =~ /DONE.ERR/
        info("- Saving process finished with ERRORS! at: #{Time.now}")
	info("  Check the log file (probably disk read error on the node...)")
      else
        info("- Saving process finished correctly at: #{Time.now}")
      end
    end
  }
  if (notDone == false)
    ns.pxeImage("#{prop.domain.value}", setPXE=false)
    Experiment.done
  end
  notDone
}

everyNS('save', 10) { |ns|
  ns.eachNode { |n|
    status = n.match('apps/*/status/')[0].to_s
    if status =~ /STARTED/
      if prop.started.value == "false"
        prop.started = "true"
        info "- SAVE_IMAGE process started at: #{Time.now}"
	info "  (this may take a while, e.g. 5min+, depending of the size of your image)"
      end
    end
  }
}

whenAllUp() {|ns|
  ns.eachNode { |n|
   n.saveImage
  }
}

