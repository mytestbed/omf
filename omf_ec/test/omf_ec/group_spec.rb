require 'test_helper'
require 'omf_ec/group'

describe OmfEc::Group do
  describe "when initialised" do
    it "must be generate unique id if :unique option is on" do
      OmfEc::Group.new('bob').id.wont_equal 'bob'
    end

    it "must use name as id if :unique option is off" do
      OmfEc::Group.new('bob', unique: false).id.must_equal 'bob'
    end
  end
end
