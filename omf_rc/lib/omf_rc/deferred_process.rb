# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

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
