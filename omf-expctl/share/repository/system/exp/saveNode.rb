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

defProperty('node', 'omf.nicta.node1', "Node to save image of")
defProperty('pxe', '1.1.6', "PXE version to use")
defProperty('domain', "#{OConfig.domain}", "Domain of the node to save")
defProperty('started', 'false', "internal flag")

OMF::Services.pxe.setBootImageNS(:ns => "#{prop.node.value}", :domain => "#{prop.domain.value}")

def clearPXE
  OMF::Services.pxe.clearBootImageNS(:ns => "#{prop.node.value}", :domain => "#{prop.domain.value}")
end

#
# Define nodes used in experiment
#
defGroup('save', Experiment.property('node')) {|n|
  n.pxeImage("#{prop.domain.value}", setPXE=true)
  n.image = "pxe-5.4"
}

everyNS('save', 10) { |ns|
  notDone = true
  ns.each { |n|
    status = n.match('apps/*/status/')[0].to_s
    if status =~ /DONE/
      notDone = false
      if status =~ /DONE.ERR/
        info("- Saving disk image of '#{n}' finished with ERRORS!")
        info("  Check the log file (probably disk read error on the node)")
      else
        info("- Saving disk image of '#{n}' finished with success.")
      end
      info("- Saving process completed at: #{Time.now}")
      info " "
    end
  }
  Experiment.done if notDone == false
  notDone
}

everyNS('save', 10) { |ns|
  ns.each { |n|
    status = n.match('apps/*/status/')[0].to_s
    if status =~ /STARTED/
      if prop.started.value == "false"
        prop.started = "true"
        info " "
        info "- Saving process started at: #{Time.now}"
        info "  (this may take a while depending on the size of your image)"
      end
    end
  }
}

onEvent(:INTERRUPT) {
  clearPXE
}

onEvent(:ALL_UP) {
  clearPXE
  group('save').each { |n|
    n.saveImage
  }
}
