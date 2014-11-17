require 'omf_common/auth'

module OmfCommon::Auth::PDP
  # Authorise job service (experiment controller) messages
  class JobService
    def initialize(opts = {})
      debug "Authorisation initialised >>> #{opts}"
    end

    def authorize(msg, &block)
      debug "Assertion: #{msg.assert}"
      debug "Message pending authorisation(#{msg.issuer})>>> #{msg}"
      sender = msg.src.address
      msg
    end
  end
end
