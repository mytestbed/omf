# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

#
# Test 1
#
# Testing one node in one group running one exec command for an already installed app
#
defProperty('res1', "unconfigured-node-1", "ID of a node")

defGroup('Actor', property.res1)

onEvent(:ALL_UP) do
  info "TEST - allGroups"
  allGroups.exec("/bin/date")

  info "TEST - group"
  group("Actor").exec("/bin/hostname -f")

  Experiment.done
end
