require 'open3'

module OmfCommon::Command
  # Execute a system command and use Open3 to capture exit status, stdout, stderr
  #
  # @example
  #
  #   OmfCommon::Command.execute("uname -a")
  def self.execute(*cmd, &block)
    result = nil
    begin
      Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thread|
        case wait_thread.value.exitstatus
        when 0
          # Exit status 0, all good, read stdout
          result = stdout.read.chomp
        when 1
          # Exit status 1, log minor error as warning
          #logger.warn stderr.read.chomp
          raise StandardError, stderr.read.chomp
        when 2
          # Exit status 2, log standard error
          #logger.error stderr.read.chomp
          raise StandardError, stderr.read.chomp
        else
          # Exit status greater than 2, log fatal error
          #logger.fatal stderr.read.chomp
          raise StandardError, stderr.read.chomp
        end
      end
    rescue Errno::ENOENT => e
      #logger.fatal e.message
      raise e
    end
    result
  end
end
