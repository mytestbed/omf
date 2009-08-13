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
Experiment.name = "imageNode"
Experiment.project = "Orbit::Admin"

defProperty('nodes', [1..8, 1..8], "Range of nodes to image")
defProperty('image', 'baseline.ndz', "Image to load on nodes")
defProperty('domain', nil, "Domain of the nodes to image")
# The following value of 800sec for timeout is based on trial imaging experiments 
defProperty('timeout', 800, "Stop the imaging process <timeout> sec after the last node has powered up")

#
# First of all, do some checks...
# - check if the requested image really exists on the Repository
url = "#{OConfig.FRISBEE_SERVICE}/checkImage?img=#{prop.image.value}"
response = NodeHandler.service_call(url, "Image does not exist")
if response.body != "OK"
  MObject.error("ERROR - The image '#{prop.image.value}' does not exist! ")
  MObject.error("ERROR - (From FrisbeeService: #{response.body})")
  Experiment.done
  exit -1
end
# - check if timeout value from command line is really an integer
if (prop.timeout.value.to_i == 0)
  MObject.error("ERROR - The timeout value '#{prop.timeout.value}' is not an integer!")
  MObject.error("ERROR - Check command line syntax.")
  Experiment.done
  exit -1
end

#
# Define the group of node to image and set them into PXE boot 
#
defGroup('image', prop.nodes) {|n|
   n.pxeImage("#{prop.domain.value}", setPXE=true)
}

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

  ns.eachNode { |n|
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
    #info "Progress(#{prog}): #{stats} min(#{nodeMin})/avg/max (#{startupDelayMax})"
    info "Progress(#{prog}): #{stats} min(#{nodeMin})/avg/max (#{startupDelayMax}) - Timeout: #{lastUpTime+prop.timeout.value-Time.now.to_i} sec."

    if (nodesDone >= nodeCnt) || ((lastUpTime+prop.timeout.value) < Time.now.to_i)
      # we are done
      info " ----------------------------- "
      info " Imaging Process Done " 
      if nodesWithErrorList.length > 0
         topoName = "system_topo_failed_#{Experiment.getDomain}"
         topoNameS = "system:topo:failed:#{Experiment.getDomain}"
         File.open("/tmp/#{Experiment.ID}-#{topoName}.rb","w") do |f|
            f.puts("# Topology name: #{topoNameS}", "# ")
            f.puts("# The following command creates a Topology wih the nodes that have failed the imaging process.")
            f.puts("# On these nodes, the 'frisbee' client did not manage to start the imaging process.")
            f.puts("# Check the nodehandler log file for the 'frisbee' client error message.", "# ")
            nsArray = []
            nodesWithErrorList.each { |n| nsArray << "[#{n.x},#{n.y}]" }
            nset = "[#{nsArray.join(",")}]"
            f.puts(" ","defTopology('#{topoNameS}', #{nset})")
         end
         info " - #{nodesWithErrorList.length} node(s) failed - See the topology file: '/tmp/#{Experiment.ID}-#{topoName}.rb'"
      end
      if nodesPendingList.length > 0
         topoName = "system_topo_timedout_#{Experiment.getDomain}"
         topoNameS = "system:topo:timedout:#{Experiment.getDomain}"
         File.open("/tmp/#{Experiment.ID}-#{topoName}.rb","w") do |f|
            f.puts("# Topology name: #{topoNameS}", "# ")
            f.puts("# The following command creates a Topology wih the nodes that have timed-out the imaging process.")
            f.puts("# These nodes did not finish imaging before the timeout limit of #{prop.timeout.value}.")
            f.puts("# These nodes most probably have some issues (disk problems ?).","# ")
            nsArray = []
            nodesPendingList.each { |n| nsArray << "[#{n.x},#{n.y}]" }
            nset = "[#{nsArray.join(",")}]"
            f.puts(" ","defTopology('#{topoNameS}', #{nset})")
         end
         info " - #{nodesPendingList.length} node(s) timed-out - See the topology file: '/tmp/#{Experiment.ID}-#{topoName}.rb'"
      end
      if nodesWithSuccessList.length > 0
         topoName = "system_topo_active_#{Experiment.getDomain}"
         topoNameS = "system:topo:active:#{Experiment.getDomain}"
         File.open("/tmp/#{Experiment.ID}-#{topoName}.rb","w") do |f|
            f.puts("# Topology name: #{topoNameS}", "# ")
            f.puts("# The following command creates a Topology wih the nodes that have successfully been imaged.","# ")
            nsArray = []
            nodesWithSuccessList.each { |n| nsArray << "[#{n.x},#{n.y}]" }
            nset = "[#{nsArray.join(",")}]"
            f.puts(" ","defTopology('#{topoNameS}', #{nset})")
         end
         info " - #{nodesWithSuccessList.length} node(s) succesfully imaged - See the topology file: '/tmp/#{Experiment.ID}-#{topoName}.rb'"
      end
      info " ----------------------------- "
      ns.pxeImage("#{prop.domain.value}", setPXE=false)
      ns.stopImageServer(Experiment.property('image'), "#{prop.domain.value}")
      Experiment.done
      notDone = false
    end
  end
  notDone
}

#
# When all the nodes in the above group are Up, then start loading the image on them
#
whenAllUp() {|ns|
  # Only execute imaging if node set is not empty!
  # (e.g. in rare occasions no node managed to come up and register to NH, when this
  # happens, we need to exit quietly from this 'whenAllUp')
  nodeCount = 0 
  ns.eachNode { |n|
    nodeCount += 1
  }
  if (nodeCount != 0)
    ns.loadImage(Experiment.property('image'), "#{prop.domain.value}")
  end
}


#defURL('/progress') {|req, res|
OMF::ExperimentController::Web.mapProc('/progress') {|req, res|
  body = []
  body << %q{
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
    <meta http-equiv="refresh" content="10">
    <title>Imaging Progress :: Orbit</title>
    <link href="resource/stylesheet/grid.css" type="text/css" rel="stylesheet"/>
  </head>

  <body>
      <h1>Imaging Progress</h1>
      <table class="grid">
}
  (1 .. OConfig.GRID_MAX_Y).each { |y|
    body << "<tr class='row'>"
    (1 .. OConfig.GRID_MAX_X).each { |x|
      n = Node[x,y]
      if (n == nil)
        body << "<td class='cell'></td>"
      elsif (n.isUp)
        body << "<td class='cell cell-up'>"
        progress = n.match('apps/builtin[1]/properties/progress/text()').to_s
        if (progress != nil)
          body << "<div class='cell-progress' style='width: #{progress}%'></div>"
        end
        body << "</td>"
      else
        body << "<td class='cell cell-down'></td>"
      end
    }
    body << "</tr>"
  }
  body << "</table></body></html>"
  res.body = body.to_s
  res['Content-Type'] = "text/html"
}

# Thierry:
#
# The defWebService is not implemented yet in the handler commands
# To be able to test PXE and Frisbee, we comment this for now
#
#defWebService('/progress') {|req, res|
#  res.body("text/html") {
#    head {
#      meta('http-equiv' => "refresh",  :content => 10)
#      title("Imaging Progress :: Orbit")
#      link(:href => "resource/stylesheet/grid.css", :type => "text/css", :rel => "stylesheet")
#    }
#    body {
#      h1("Imaging Progress")
#      table(:class => "grid") {
#       (1 .. OConfig.GRID_MAX_Y).each { |y|
#          tr(:class => 'row') {
#           (1 .. OConfig.GRID_MAX_X).each { |x|
#              n = Node[x,y]
#              if (n == nil)
#                td(:class => 'cell')
#              elsif (n.isUp)
#                td(:class => 'cell cell-up') {
#                  progress = n.match('apps/builtin[1]/properties/progress/text()').to_s
#                  if (progress != nil)
#                    div(:class => 'cell-progress', :style => 'width: #{progress}%')
#                  end
#                }
#              else
#                td(:class => 'cell cell-down')
#              end
#            } # each x
#          } # tr
#        } # each y
#      } # table
#    } # body
#  }
#}
