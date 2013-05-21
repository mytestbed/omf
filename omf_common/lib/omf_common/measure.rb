# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'oml4r'
module OmfCommon
  class Measure
    @@enabled = false
    def Measure.enabled? ; @@enabled end
    def Measure.enable ; @@enabled = true end
  end
end
