require 'test_helper'
require 'omf_rc/resource_proxy/generic_application'



describe OmfRc::ResourceProxy::GenericApplication do

  before do
    @app_test = OmfRc::ResourceFactory.new(:generic_application, { hrn: 'an_application' })
    @app_test.comm = MiniTest::Mock.new
    @app_test.comm.expect :publish, nil, [String,OmfCommon::Message] 
  end

  describe "when initialised" do
    it "must respond to an 'on_app_event' call back" do
      #OmfRc::ResourceProxy::GenericApplication.method_defined?(:on_app_event).must_equal true
      @app_test.must_respond_to :on_app_event
    end

    it "must have its state property set to 'stop'" do
      @app_test.request_state.to_sym.must_equal :stop
    end

    it "must be able to configure its basic properties" do
      basic_prop = %w(binary_path pkg_tarball pkg_ubuntu pkg_fedora force_tarball_install map_err_to_out tarball_install_path)
      basic_prop.each do |p|
        @app_test.method("configure_#{p}".to_sym).call('foo')
        @app_test.method("request_#{p}".to_sym).call.must_equal 'foo'
      end
    end

    it "must be able to tell which platform it is running on (either: unknown | ubuntu | fedora)" do
      @app_test.request_platform.must_match /unknown|ubuntu|fedora/
    end
  end

  describe "when receiving an event from a running application instance" do
    it "must publish an INFORM message to relay that event" do
      @app_test.on_app_event('STDOUT', 'app_instance_id', 'Some text here').must_be_nil
    end

    it "must increments its event_sequence after publishig that INFORM message" do
      i = @app_test.property.event_sequence
      @app_test.on_app_event('STDOUT', 'app_instance_id', 'Some text here')
      @app_test.property.event_sequence.must_equal i+1
    end

    #it "must switch its state to 'stop' if the event is of a type 'DONE'" do
    #end

    #it "must switch its installed property to 'true' if the event is 'DONE.OK' and the app_id's suffix is '_INSTALL'" do
    #end
  end


end
