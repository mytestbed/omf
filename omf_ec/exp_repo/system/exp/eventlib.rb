#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
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
# = eventlib.rb 
#
# == Description
#
# This Ruby file contains various common Event declarations, which the EC will 
# load before the user's experiment file
#

#
# This provide some default Event definition that the user may use in his 
# experiment, without having to worry about how to define them.
# To start one of the event monitoring defined here, the user need to associate 
# at least one block of tasks to it, using the onEvent() OEDL call.
# See the OEDL documentation for more info and a tutorial
#

defEvent(:ALL_UP_AND_INSTALLED) do |event|
  node_status = allGroups.state("status/@value")
  app_status = allGroups.state("apps/app/status/@value")
  if allEqual(node_status, "UP") && allEqual(app_status, "INSTALLED.OK")
    event.fire 
  end
end

defEvent(:ALL_UP) do |event|
  node_status = allGroups.state("status/@value")
  event.fire if allEqual(node_status, "UP")
end

defEvent(:ALL_INTERFACE_UP) do |event|
  iface_status = allGroups.state("net/*/*/current/@status")
  #info "TDEBUG - #{if_status.join(" ")}"
  event.fire if allEqual(iface_status, "CONFIGURED.OK")
end

defEvent(:EXPERIMENT_DONE) do |event|
  exp_status = Experiment.state("status/text()")
  event.fire if allEqual(exp_status, "DONE")
end

onEvent(:EXPERIMENT_DONE, true) do |event|
  Experiment.close
end

defEvent(:INTERRUPT, 1) do |event|
  exp_status = Experiment.state("status/text()")
  event.fire if allEqual(exp_status, "INTERRUPTED")
end

onEvent(:INTERRUPT) do |event|
  MObject.info(:INTERRUPT, "\n\nUser issued an Interruption. Stopping the experiment now! Please wait...\n")
  Experiment.done
end

defEvent(:NO_USER_DEFINED_EVENTS) do |event|
  if Experiment.running? && !Experiment.disconnection_allowed?
    if Event.empty?(:ignore => [:EXPERIMENT_DONE, :NO_USER_DEFINED_EVENTS])
      event.fire 
    end
  end
end

onEvent(:NO_USER_DEFINED_EVENTS) do |event|
  warn " "
  warn "Warning!!! Your experiment has no user-defined events!"
  warn "It is likely that nothing will happen from now one..."
  warn "Press CTRL-C only ONCE to stop your experiment.\n"
  # An alternative... not sure what is the best here, for now use the above
  # warn "Closing down your experiment now..."
  # Experiment.done
end



