require 'open3'
require 'omf_common/logger'

class OmfRc::Cmd
  def self.exec(*cmd)
    Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thread|
      case wait_thread.value.exitstatus
      when 0
        stdout.read.chomp
      when 1
        omf_logger.warn stderr.read.chomp
        nil
      when 2
        omf_logger.error stderr.read.chomp
        nil
      end
    end
  end
end
