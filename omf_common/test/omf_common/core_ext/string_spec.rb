require 'test_helper'

describe String do
  describe "when given a string" do
    it "must response to to_n, camelcase, constant" do
      "100.0".ducktype.must_equal 100.0
      "i_am_a_string".ducktype.must_equal "i_am_a_string"
      "i_am_a_string".camelcase.must_equal "IAmAString"
      module IAmAString; end
      "i_am_a_string".camelcase.constant.must_equal IAmAString
      module IAmAString::Test; end
      "IAmAString::Test".constant.must_equal IAmAString::Test
    end
  end
end

