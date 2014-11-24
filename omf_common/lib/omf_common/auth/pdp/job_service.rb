require 'omf_common/auth'
require 'omf_common/auth/assertion'

module OmfCommon::Auth::PDP
  # Authorise job service (experiment controller) messages
  class JobService
    def initialize(opts = {})
      @slice = opts[:slice]
    end

    def authorize(msg, &block)
      debug "Assertion: #{msg.assert}"

      assert = OmfCommon::Auth::Assertion.new(msg.asesrt)

      unless assert.verify
        return nil
      end

      # Check current slice with slice specified in assertion
      if assert.content =~ /(.+) can use slice (.+)/
        && $1 == msg.src.address
        && $2 == @slice
        return msg
      else
        return nil
      end
    end
  end
end
