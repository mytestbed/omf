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

      if msg.assert.nil?
        warn 'No assertion found, drop it'
        return nil
      end

      assert = OmfCommon::Auth::Assertion.new(msg.assert)

      unless assert.verify
        return nil
      else
        info "#{msg.src.address} tells >> #{assert.iss} says >> #{assert.content}"
      end

      # Check current slice with slice specified in assertion
      if assert.content =~ /(.+) can use slice (.+)/ &&
        $1 == msg.src.id.to_s &&
        $2 == @slice.to_s

        info 'Deliver this message'

        block.call(msg) if block
        return msg
      else
        warn 'Drop it'
        return nil
      end
    end
  end
end
