require 'test_helper'
require 'omf_rc/resource_factory'

include OmfRc::ResourceProxy

module OmfRc::ResourceProxy
  module Mock
    include OmfRc::ResourceProxy
    register_proxy :mock

    def test
    end

    def configure_property(property, value)
      super
      raise StandardError, 'Get your attention'
    end
  end
end

describe Mock do
  before do
    @resource = OmfRc::ResourceFactory.new(:mock, :uid => 'suzuka', :properties => {:mock_property => "test"})
  end

  describe "when child resource with a known type" do
    it "must load methods from related module correctly" do
      @mock = @resource.create(:mock, uid: 'mock')
      @mock.must_respond_to :test
      proc { @mock.must_send [@mock, :configure_property, 'test', 'test'] }.must_raise StandardError
    end
  end
end

