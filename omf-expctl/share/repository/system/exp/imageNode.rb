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
# = imageNode.rb
#
# == Description
#
# This file describes the Experiment that is used to image the nodes within OMF.
# (In OMF, loading a disk image on a node is treated as an 'experiment' itself)
#

# Define the experiment properties
Experiment.name = "imageNode"
Experiment.project = "Orbit::Admin"
defProperty('nodes', 'system:topo:all', "Nodes to image")
defProperty('image', 'baseline.ndz', "Image to load on nodes")
defProperty('domain', "#{OConfig.domain}", "Domain of the nodes to image")
defProperty('outpath', "/tmp", "Path where to place the topology files resulting from this image")
defProperty('outprefix', "#{Experiment.ID}", "Prefix to use for the topology files resulting from this image")
# The following value of 1200sec for timeout is based on trial imaging experiments 
defProperty('timeout', 1200, "Stop the imaging process <timeout> sec after the last node has powered up")

# Define some constants
MSG_CHECKINFAILED = <<TEXT
# This creates a Topology with the resources which did not check in to the load experiment.
# These nodes may have failed to boot into the PXE image or start the RC from within.
#
TEXT
MSG_IMAGEFAILED = <<TEXT
# This creates a Topology with the resources for which the image loading failed.
# On these resources, the 'frisbee' client may have raised an error during its execution.
# Please check the EC log file for the 'frisbee' client error message.
#
TEXT
MSG_TIMEOUT = <<TEXT
# This creates a Topology with the resources for which the image loading timed out.
# These nodes did not finish imaging before the timeout limit.
# Most of the time this is caused by some disk or network problems.
#
TEXT
MSG_SUCCESS = <<TEXT
# This creates a Topology with the resources which have successfully been imaged.
#
TEXT
MESSAGES = {:checkinfailed => MSG_CHECKINFAILED, :imagefailed => MSG_IMAGEFAILED, :timeout => MSG_TIMEOUT, :success => MSG_SUCCESS}


#
# First of all, do some checks...
# - check if the requested image really exists on the Repository
#
#url = "#{OConfig[:ec_config][:frisbee][:url]}/checkImage?img=#{prop.image.value}&domain=#{prop.domain.value}"
#response = NodeHandler.service_call(url, "Image does not exist")
response = OMF::Services.frisbee.checkImage(:img => "#{prop.image.value}", :domain => "#{prop.domain.value}")
if response.elements[1].name != "OK"
  MObject.error("Frisbee Service Call", response.root.text)
  Experiment.done
  exit
end
# - check if timeout value from command line is really an integer
if (prop.timeout.value.to_i == 0)
  MObject.error("The timeout value '#{prop.timeout.value}' is not an integer!")
  MObject.error("Check command line syntax.")
  Experiment.done
  exit -1
end

@allNodes = []

#
# Define the group of node to image and set them into PXE boot 
#
defGroup('image', prop.nodes) {|ns|
   ns.image = "pxe-5.4"
   ns.each { |n| @allNodes << n }
}

url = "#{OConfig[:ec_config][:pxe][:url]}/setBootImageNS?domain=#{prop.domain.value}&ns=#{@allNodes.map{|n| n.to_s }.join(',')}"
NodeHandler.service_call(url, "Error setting PXE symlinks")

def clearPXE
  url = "#{OConfig[:ec_config][:pxe][:url]}/clearBootImageNS?domain=#{prop.domain.value}&ns=#{@allNodes.map{|n| n.to_s }.join(',')}"
  NodeHandler.service_call(url, "Error removing PXE symlinks")
end

def outputTopologyFile(type, nset)
  begin
    filename = "#{prop.outpath.value}/#{prop.outprefix.value}-topo-#{type}.rb"
    toponame = "#{prop.outprefix.value}-topo-#{type}"
    
    # we need to put the array back into the original order
    # since nodes were added in the order they signed in
    sortedNodes = Array.new(@allNodes)
    sortedNodes.delete_if {|n| !nset.include?(n) }
    sortedNodes.map!{|n| n.to_s }
    File.open(filename, "w") do |f|
      f.puts("# Topology name: #{toponame}", "# ")
      f.puts(MESSAGES[type])
      f.print("defTopology('#{toponame}', '")
      f.print(sortedNodes.join(","))
      f.puts "')"
    end
    return filename
  rescue Exception => err
    MObject.warn("exp", "Could not write result topology file: '#{filename}' (#{err})")
    MObject.warn("exp", "(Most probably imaging was OK, but result file could not be created)")
  end
  return nil
end

#
# Every 10s check the state of the imaging process and report accordingly
#
everyNS('image', 10) { |ns|
  nodesUp = 0
  nodesDone = 0
  nodesWithError = 0
  nodesWithErrorList = []
  nodesWithSuccessList = []
  nodesPendingList = []
  nodeCnt = 0
  progMax = 0
  progMin = 100
  nodeMin = nil
  progSum = 0
  startupDelayMax = 0
  report = true
  notDone = true
  lastUpTime = 0

  ns.each { |n|
    nodeCnt += 1
    if n.isUp
#      nodesUp += 1
      prog = n.match('apps/*/*/progress/text()')[-1].to_s.to_i
#puts n
#puts n.match('apps/*/*/progress')
      progSum += prog
      progMax = prog if prog > progMax
      if prog < progMin
        progMin = prog
        nodeMin = n
      end
      startupDelay = n.checkedInAt.to_i - n.poweredAt.to_i
      startupDelayMax = startupDelay if startupDelay > startupDelayMax
      if n.poweredAt.to_i > lastUpTime
        lastUpTime = n.poweredAt.to_i
      end	

      status = n.match('apps/*/status/')[0].to_s
      nodesDone += 1 if status =~ /DONE/
      if status =~ /DONE.ERR/
        nodesWithError += 1
        nodesWithErrorList << n
      elsif status =~ /DONE.OK/
        nodesWithSuccessList << n
      else
        nodesPendingList << n
      end
    else
      # wait with reporting until everybody is up
      report = false
    end
  }
  if report
    progAvg = nodeCnt > 0 ? progSum / nodeCnt : 0
    stats = "#{progMin}/#{progAvg}/#{progMax}"
    prog = "#{nodesDone}/#{nodesWithError}/#{nodeCnt}"
    timeLeft = lastUpTime+prop.timeout.value-Time.now.to_i
    info "Progress(#{prog}): #{stats} min(#{nodeMin})/avg/max (#{startupDelayMax}) - Timeout: #{timeLeft} sec."

    if (nodesDone >= nodeCnt) || ((lastUpTime+prop.timeout.value) < Time.now.to_i)
      # we are done
      info " ----------------------------- "
      info " Imaging Process Done " 
      nodesWhichNeverCheckedIn = @allNodes - nodesWithErrorList - nodesPendingList - nodesWithSuccessList
      if (l = nodesWhichNeverCheckedIn.length) > 0
        f = outputTopologyFile(:checkinfailed, nodesWhichNeverCheckedIn)
        info " #{l} node#{"s" if l>1} failed to check in - Topology saved in '#{f}'"
      end
      if (l = nodesWithErrorList.length) > 0
        f = outputTopologyFile(:imagefailed, nodesWithErrorList)
        info " #{l} node#{"s" if l>1} failed to image the disk - Topology saved in '#{f}'"
      end
      if (l = nodesPendingList.length) > 0
        f = outputTopologyFile(:timeout, nodesPendingList)
        info " #{l} node#{"s" if l>1} timed out - Topology saved in '#{f}'"
      end
      if (l = nodesWithSuccessList.length) > 0
        f = outputTopologyFile(:success, nodesWithSuccessList)
        info " #{l} node#{"s" if l>1} successfully imaged - Topology saved in '#{f}'"
      end
      info " ----------------------------- "
      ns.stopImageServer(Experiment.property('image'), "#{prop.domain.value}")
      Experiment.done
      notDone = false
    end
  end
  notDone
}

onEvent(:INTERRUPT) {
  clearPXE
}

#
# When all the nodes in the above group are Up, then start loading the image on them
#
onEvent(:ALL_UP) {
  clearPXE
  # Only execute imaging if node set is not empty!
  # (e.g. in rare occasions no node managed to come up and register to EC, when this
  # happens, we need to exit quietly from this 'onEvent(:ALL_UP)')
  nodeCount = 0
  group('image').each { |n|
    nodeCount += 1
  }
  if (nodeCount != 0)
    group('image').loadImage(Experiment.property('image'), "#{prop.domain.value}")
  end
}


##defURL('/progress') {|req, res|
#OMF::Common::Web.mapProc('/progress') {|req, res|
#  body = []
#  body << %q{
#<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
#<html>
#  <head>
#    <meta http-equiv="refresh" content="10">
#    <title>Imaging Progress :: Orbit</title>
#    <link href="resource/stylesheet/grid.css" type="text/css" rel="stylesheet"/>
#  </head>
#
#  <body>
#      <h1>Imaging Progress</h1>
#      <table class="grid">
#}
#  # TODO: port this to OMF 5.4
#  # (1 .. OConfig[:tb_config][:default][:y_max]).each { |y|
#  #   body << "<tr class='row'>"
#  #   (1 .. OConfig[:tb_config][:default][:x_max]).each { |x|
#  #     n = Node[x,y]
#  #     if (n == nil)
#  #       body << "<td class='cell'></td>"
#  #     elsif (n.isUp)
#  #       body << "<td class='cell cell-up'>"
#  #       progress = n.match('apps/builtin[1]/properties/progress/text()').to_s
#  #       if (progress != nil)
#  #         body << "<div class='cell-progress' style='width: #{progress}%'></div>"
#  #       end
#  #       body << "</td>"
#  #     else
#  #       body << "<td class='cell cell-down'></td>"
#  #     end
#  #   }
#  #   body << "</tr>"
#  # }
#  body << "</table></body></html>"
#  res.body = body.to_s
#  res['Content-Type'] = "text/html"
#}
#
