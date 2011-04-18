#
# This experiment sends a reset to all the resources which are associated to it
# Typically, one would run this experiment with a specific Experiment ID, with 
# the following command:
#   omf-5.3 exec -e your_experiment_id system:exp:reset
#
property.resetDelay = 1
property.resetTries = 0
info "---------------"
info "  "
info "  This management experiment will send a RESET to all resources"
info "  in the experiment with the ID: #{Experiment.ID}"
info "  (Typically one would run this experiment with the following"
info "   command: omf-5.3 exec -e your_experiment_id system:exp:reset)"
info "  "
info "  Please wait a few second now..."
info "  "
info "---------------"
defGroup("reset", "")
ECCommunicator.instance.send_reset
Experiment.done
