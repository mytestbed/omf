# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'

describe String do
  describe "when given a string" do
    it "must response to ducktype" do
      "100".ducktype.must_equal 100
      "100.0".ducktype.must_equal 100.0
      "i_am_a_string".ducktype.must_equal "i_am_a_string"
    end
  end
end

