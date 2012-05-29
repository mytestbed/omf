# To be used for handling long running processes
#
class OmfRc::DeferredProcess
  include EM::Deferrable

  # Pass a block of long running process
  #
  def fire(&block)
    raise ArgumentError, "Missing code block to be executed" if block.nil?

    EM.defer do
      begin
        result = block.call
        succeed result
      rescue => e
        fail e
      end
    end
  end
end
