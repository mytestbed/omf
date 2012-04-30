require 'open3'
require 'omf_common'

module OmfRc::Cmd
  def self.exec(command, &block)
    EM.system(command, &block)
  end
end
