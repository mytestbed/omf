# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

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
          logger.warn stderr.read.chomp
        when 2
          # Exit status 2, log standard error
          logger.error stderr.read.chomp
        else
          # Exit status greater than 2, log fatal error
          logger.fatal stderr.read.chomp
        end
      end
    rescue Errno::ENOENT => e
      logger.fatal e.message
    end
    result
  end
end
