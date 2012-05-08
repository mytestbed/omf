# This is a utility  definition module, which can be included in proxy definition module
module OmfRc::Util::UMock
  # Include this module which provides dsl
  include OmfRc::Util

  # Let the world know it is available
  register_utility :u_mock

  # Register a function for configure property, a method called configure_very_important_property(value) will be added to the resource instance.
  register_configure :very_important_property do
    # These define what to be done for configuring this property
    raise StandardError, 'We just did something very important, I need your attention'
  end

  # Register a function for request property, a method called request_very_important_property() will be added to the resource instance.
  register_request :very_important_property do
    # These define what to be done for requesting this property, should return a value of the property at the end
    "Very important property's value"
  end
end

# This is a resource proxy definition module, which can be included dynamically by resource factory at the time of creating new resource.
module OmfRc::ResourceProxy::Mock
  # Include this module which provides dsl
  include OmfRc::ResourceProxy
  include OmfRc::Util

  # Let the world know it is available
  register_proxy :mock

  # Include the utility we just defined
  utility :u_mock

  # The code inside the block will be called at the end of resource initialisation.
  register_bootstrap do
    logger.warn 'I am starting up, but have nothing to do there'
  end

  # The code inside the block will be called at the end of releasing a resource.
  register_cleanup do
    logger.warn 'I am shutting down, but have nothing to do there'
  end

  # Of course you can hack this module by defining additional methods. The methods defined here will be available to the resource instance as well
  def test
  end
end


# We can then use resource factory method to create a resource instance.
#
# This does following behind the scene
#
# * Extend the instance with mock resource module we just defined.
# * If additional options provided for pubsub communicator, a communicator instance will be created and attached to this mock resource instance.
# * If bootstrap/init hook provided in the module, they will be executed
mock = OmfRc::ResourceFactory.new(:mock)

# And then we can do these method calls
mock.configure_very_important_property('test') do
  puts 'configure finished'
end

mock.request_very_important_property do |value|
  puts value
end

mock.test
