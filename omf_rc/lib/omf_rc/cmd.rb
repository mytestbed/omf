require 'omf_common'

module OmfRc::ProcessHandler
  def initialize *args
    @callback = args[0]
    @result = { success: "", error: "" }
  end

  def receive_data data
    @result[:success] << data
  end

  #def receive_stderr data
  #  @result[:error] << data
  #end

  def unbind
    @callback.call(@result)
  end
end

module OmfRc::Cmd
  class << self
    def exec(command, &block)
      EM.popen(command, OmfRc::ProcessHandler, block)
    end
  end
end
