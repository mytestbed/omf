# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

# This OEDL script implements a timeout timer for resources to checked-in an 
# experiment. When it is loaded as part as another experiment, it will wait
# for the specified time in the experiment property 'oedl_timeout'. When that
# wait is over, it checks if all resources defined in the experiment have 
# joined all their groups (also as defined in the experiment). If not, then
# it stops the experiment.
#
# The default timeout value is set here to 120 s. To modify that you should
# set in your experiment the oedl_timeout property to the desired timeout in 
# second. You must do that prior to or as you load this script.
#
# For example, in your OEDL experiment:
#   
#  load_oedl('omf_ec/backward/timeout_resources', { oedl_timeout: 180 })
#
begin 
  property.oedl_timeout
rescue
  defProperty('oedl_timeout',120,'default timeout in second')
end

info "Waiting for all resources to join... (timeout set to #{property.oedl_timeout} s)"
after property.oedl_timeout.to_i do
 unless all_nodes_up?(OmfEc.experiment.state) 
   info "Waited #{property.oedl_timeout} s for all resources to join, but still some missing! Aborting the experiment execution now!"
   Experiment.done
 end
end
