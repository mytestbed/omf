# Implement your own resource proxy

## Before we could start

Install a XMPP server. [Installation notes for Openfire](https://omf.mytestbed.net/projects/omf/wiki/Installation_Guide_54#Configuring-XMPP)

Enable in-band registration support (XEP-0077) on the XMPP server if you want to automatically create the users by the time of connection.

If your XMPP server has anonymous authentication enabled, you might not have permissions to create pubsub nodes when connected anonymously, to avoid the trouble, please turn off the anonymous authentication mode.

Now we need to nstall omf\_rc pre-release gems

    gem install omf_rc --pre

## Scenario

Suppose we are managing a formula 1 team's garage, and we want to test the engines' we have, simply by adjusting the throttle and observing the engines' RPM. Unless you had the opportunity to connect your laptop to a real formula 1 engine, we can assume that all we need here is a mock up engine written in ruby.

We will build a garage controller (resource controller) acts as the proxy to the garage and engines, and an engine test controller, which asks garage controller to provide an engine and perform some throttle adjustments, while monitoring engines' RPM.

### Files

If you want to dive into the code right now, these are the two annotated files used for this example:

* [Garage controller (server side)](https://github.com/mytestbed/omf/blob/master/doc/garage_controller.rb)
* [Engine test controller (client side)](https://github.com/mytestbed/omf/blob/master/doc/test_controller.rb)

### Resource controller script skeleton (server side)

Firstly, we need a resource controller script runs on the server side, which contains an instance of resource proxy represents 'garage', we can then use resource factory method to create such

    OmfRc::ResourceFactory.new(:garage, options)

This does following behind the scene

* Extend the instance with resource proxy module named 'garage' (_should be defined first_).
* If additional options provided for pubsub communicator, a communicator instance will be created and attached to this resource proxy instance.
* If before\_ready hook provided in the module, they will be executed.

Refer to [OmfRc::ResourceFactory](../../OmfRc/ResourceFactory) for implementation.

We start with this skeleton, save it as garage\_controller.rb

    #!/usr/bin/env ruby

    require 'omf_rc'
    require 'omf_rc/resource_factory'
    $stdout.sync = true

    options = {
      user: 'alpha',
      password: 'pw',
      server: 'localhost', # XMPP server domain
      uid: 'mclaren', # Id of the garage (resource)
    }

    EM.run do
      # Use resource factory method to initialise a new instance of garage
      garage = OmfRc::ResourceFactory.new(:garage, options)
      # Let garage connect to XMPP server
      garage.connect

      # Disconnect garage from XMPP server, when these two signals received
      trap(:INT) { garage.disconnect }
      trap(:TERM) { garage.disconnect }
    end

### Resource proxy mixin module definition

The above script will fail to start, complaining that resource proxy of type 'garage' couldn't be found in the resource factory. Thus we need to define it, register it, just before the main event machine loop (before the line 'EM.run do')

    module OmfRc::ResourceProxy::Garage
      include OmfRc::ResourceProxyDSL

      register_proxy :garage
    end

Run the script again, it should prompt user alpha got connected.

We also need definition for engines, since their instances will be created later (via 'create' messages published by the client script, through XMPP).

    module OmfRc::ResourceProxy::Engine
      include OmfRc::ResourceProxyDSL

      register_proxy :engine
    end

A resource proxy mixin module represents the functionalities the resource could provide, for example, this engine proxy can provide adjustable throttle to be configured, RPM value to be requested, etc.. The features defined here will be available to the engine proxy instance by the time it is created by ResourceFactory.

### Add more features to engine

Now we are going to add some features by including the following inside the engine proxy module:

These register DSL methods will normally take a name parameter, and a block which be will be executed at the runtime.

An optional yielded variable could used if your actions inside the block need access inside the context of resource proxy itself, i.e. getting or updating the instance object where this mixin module will be applied to.

Normally we don't need to record the state of a real resource inside our resource proxy entities (e.g. the available memory of a running physical machine). In case you need to maintain the state, resource proxy abstract class provides a :metadata attribute (which is a [Hashie::Mash] (https://github.com/intridea/hashie#mash) object), for keeping these information inside the instances.

For more information regarding these DSL methods, go to the section [Full DSL methods list](#Full_DSL_methods_list)


    # before_ready hook will be called during the initialisation of the resource instance
    #
    hook :before_ready do |resource|
      resource.metadata.max_power ||= 676 # Set the engine maximum power to 676 bhp
      resource.metadata.provider ||= 'Honda' # Engine provider defaults to Honda
      resource.metadata.max_rpm ||= 12500 # Maximum RPM of the engine is 12,500
      resource.metadata.rpm ||= 1000 # After engine starts, RPM will stay at 1000 (i.e. engine is idle)
      resource.metadata.throttle ||= 0.0 # Throttle is 0% initially

      # The following simulates the engine RPM, it basically says:
      # * Applying 100% throttle will increase RPM by 5000 per second
      # * Engine will reduce RPM by 250 per second when no throttle applied
      # * If RPM exceed engine's maximum RPM, the engine will blow.
      #
      EM.add_periodic_timer(1) do
        unless resource.metadata.rpm == 0
          raise 'Engine blown up' if resource.metadata.rpm > resource.metadata.max_rpm
          resource.metadata.rpm += (resource.metadata.throttle * 5000 - 250)
          resource.metadata.rpm = 1000 if resource.metadata.rpm < 1000
        end
      end
    end

    # before_release hook will be called before the resource is fully released, shut down the engine in this case.
    #
    hook :before_release do |resource|
      # Reduce throttle to 0%
      resource.metadata.throttle = 0.0
      # Reduce RPM to 0
      resource.metadata.rpm = 0
    end

    # We want RPM to be availabe for requesting
    request :rpm do |resource|
      if resource.metadata.rpm > resource.metadata.max_rpm
        raise 'Engine blown up'
      else
        resource.metadata.rpm.to_i
      end
    end

    # We want some default metadata to be availabe for requesting
    %w(provider max_power max_rpm).each do |attr|
      request attr do |resource|
        resource.metadata[attr]
      end
    end

    # We want throttle to be availabe for configuring (i.e. changing throttle)
    configure :throttle do |resource, value|
      resource.metadata.throttle = value.to_f / 100.0
    end

### Engine test controller script (client side)

Experiment controller is not available yet, so we need to use pubsub comm (communicator) from omf\_common library to interact with the XMPP system, i.e. sending out operation messages and capturing the inform messages; and unfortunately this made the test script a bit complicated.

    #!/usr/bin/env ruby

    require 'omf_common'
    $stdout.sync = true

    include OmfCommon

    options = {
      user: 'bravo',
      password: 'pw',
      server: 'localhost', # XMPP pubsub server domain
      uid: 'mclaren', # The garage's name, we used the same name in the garage_controller.
      pubsub_host: 'pubsub'  # The host name of pubsub system
    }

    # We will use Comm directly, with default DSL implementaion :xmpp_blather
    comm = Comm.new(:xmpp_blather)
    host = nil

    # Then we can register event handlers to the communicator
    #
    # Event triggered when connection is ready
    comm.when_ready do
      logger.info "CONNECTED: #{comm.jid.inspect}"
      host = "#{options[:pubsub_host]}.#{comm.jid.domain}"

      # We assume that a garage resource proxy instance is up already, so we subscribe to its pubsub node
      comm.subscribe(options[:uid], host) do |e|
        if e.error?
          comm.disconnect(host)
        else
          # If subscribed, we publish a 'create' message, 'create' a new engine for testing
          comm.publish(
            options[:uid],
            Message.create { |v| v.property('type', 'engine') },
            host)
        end
      end
    end

    # Triggered when new messages published to the nodes I subscribed to
    comm.node_event do |e|
      e.items.each do |item|
        begin
          # Parse the message (pubsub item payload)
          message = Message.parse(item.payload)
          # We are only interested in inform messages for the moment
          if message.operation == :inform
            inform_type = message.read_content("inform_type")
            case inform_type
            when 'CREATED'
              engine_id = message.read_content("resource_id")
              logger.info "Engine #{engine_id} ready for testing"
            when 'STATUS'
              message.read_element("//property").each do |p|
                logger.info "#{p.attr('key')} => #{p.content.strip}"
              end
            when 'FAILED'
              logger.error message.read_content("error_message")
            when 'RELEASED'
              logger.warn "Engine turned off (resource released)"
            end
          end
        rescue => e
          logger.error "#{e.message}\n#{e.backtrace.join("\n")}"
        end
      end
    end

    EM.run do
      comm.connect(options[:user], options[:password], options[:server])
      trap(:INT) { comm.disconnect(host) }
      trap(:TERM) { comm.disconnect(host) }
    end

### More actions on engine test controller (client side)

Once we have the engine ready (i.e. we received notify message 'CREATED'), we can subscribe to its pubsub node, and publish additional instructions to the engine.

Add the following code after the line "logger.info "Engine #{engine\_id} ready for testing"

    comm.subscribe(engine_id, host) do
      # Now engine is ready, we can ask for some information about the engine
      comm.publish(engine_id,
                   Message.request do |v|
                     v.property('max_rpm')
                     v.property('provider')
                     v.property('max_power')
                   end,
                   host)

      # We will check engine's RPM every 1 second
      EM.add_periodic_timer(1) do
        comm.publish(engine_id,
                     Message.request { |v| v.property('rpm') },
                     host)
      end

      # Now we will apply 50% throttle to the engine
      comm.publish(engine_id,
                   Message.configure { |v| v.property('throttle', '50') },
                   host)

      # Some time later, we want to reduce the throttle to 0, to avoid blowing up the engine
      EM.add_timer(5) do
        comm.publish(engine_id,
                     Message.configure { |v| v.property('throttle', '0') },
                     host)
      end

      # 20 seconds later, we will 'release' this engine, i.e. shut it down
      EM.add_timer(20) do
        comm.publish(engine_id,
                     Message.release,
                     host)
      end
    end

## Organise resource proxy modules

### Define inline

If you have a rather simple resource controller, with minimal set of features, like the ones described in this tutorial, you could just define these modules as part of the RC script.

### Include resource proxy modules in the default package

The default location of resource proxy definition files are located in the directory [omf\_rc/lib/omf\_rc/resource\_proxy](https://github.com/mytestbed/omf/tree/master/omf_rc/lib/omf_rc/resource_proxy).

If you wish your feature set could be available as part of the default package, save them under this default directory, following this naming convention: OmfRc::ResourceProxy::Engine will register a proxy named :engine, and saved to file omf\_rc/lib/omf\_rc/resource\_proxy/engine.rb

To load these default resource proxies, simple call a load method provided by ResourceFactory class in your resource controller script (e.g. engine\_control.rb)

    OmfRc::ResourceFactory.load_default_resource_proxies

Commit your definition files into the git repository and simply send us a pull request.

### Package your proxy definition files as OMF extension gem

You could also package your proxy definition files into separate gems, if you feel they should not go into the default RC package.

This process is rather simple, you can check an example gem based on this tutorial here:

https://github.com/jackhong/omf_rc_foo

### Refactor common features into resource utilities

If a set of features can be shared among different types of resources, it is a good idea to refactor them into resource utilities.

Take this engine test example, if we have more than one type of engine needs to be tested, and they could all be able to adjust throttle, we can create a utility for this.

    module OmfRc::Util::Throttle
      include OmfRc::ResourceProxyDSL

      configure :throttle do |resource, value|
        resource.metadata.throttle = value.to_f / 100.0
      end
    end

Then include this utility inside the engine resource proxy file by using:

    utility :throttle

You could also overwrite a property definition provided by the utility, by registering it again using the same name.

## Full DSL methods list

In the previous example, we use method register\_proxy to register resource proxy, request to provide property to be requested, etc. They are all part of resource proxy DSL, and provided by included module resource\_proxy\_dsl.

    include OmfRc::ResourceProxyDSL

The full list of resource proxy DSL can be found here: [DSL API](../../OmfRc/ResourceProxyDSL/ClassMethods)
