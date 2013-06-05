# Copyright (c) 2013 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

class Hash
  def joined?(*group_ids)
    self[:membership] && group_ids.any? { |g_id| self[:membership].include?(g_id) }
  end
end

