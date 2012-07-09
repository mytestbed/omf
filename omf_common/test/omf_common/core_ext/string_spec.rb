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

