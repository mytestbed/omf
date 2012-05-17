require 'test_helper'
require 'omf_rc/resource_factory'

include OmfRc::ResourceProxy

module OmfRc::Util::UMock
  include OmfRc::ResourceProxyDSL

  register_utility :u_mock

  register_configure :very_important_property do
    raise StandardError, 'We just did something very important, I need your attention'
  end

  register_request :very_important_property do
    "Very important property's value"
  end
end

module OmfRc::ResourceProxy::Mock
  include OmfRc::ResourceProxyDSL

  register_proxy :mock

  utility :u_mock

  register_bootstrap do
    logger.debug 'I am starting up, but have nothing to do there'
  end

  register_cleanup do
    logger.debug 'I am shutting down, but have nothing to do there'
  end

  def test
  end
end

describe Mock do
  before do
    @resource = OmfRc::ResourceFactory.new(:mock, :uid => 'suzuka', :properties => {:mock_property => "test"})
  end

  describe "when child resource with a known type" do
    it "must load methods from related module correctly" do
      @resource.create(:mock, uid: 'mock') do |mock|
        mock.must_respond_to :test
        mock.must_respond_to :configure_very_important_property
        mock.must_respond_to :request_very_important_property
        proc { mock.configure_very_important_property('test') }.must_raise StandardError
        mock.request_very_important_property do |value|
          value.must_equal "Very important property's value"
        end
      end
    end
  end
end

