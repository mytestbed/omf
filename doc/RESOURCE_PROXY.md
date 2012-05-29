# Extend resource proxy

## Where to put the files

The default location of resource proxy definition files are located in the directory [omf\_rc/lib/omf\_rc/resource_proxy](https://github.com/mytestbed/omf/tree/master/omf_rc/lib/omf_rc/resource_proxy).

Therefore if you would like to implement new resource proxy, for example, for audio device, called audio, simple create a file named audio.rb, and define a module named OmfRc::ResourceProxy::Audio

    module OmfRc::ResourceProxy::Audio
      include OmfRc::ResourceProxyDSL

      register_proxy :audio
    end

## DSL

In the previous example, we use a method register_proxy to register audio resource proxy. It is provided by included module resource_proxy_dsl.

The full list of resource proxy DSL can be found here: [DSL API](../../OmfRc/ResourceProxyDSL/ClassMethods)

## Resource life-cycle and messaging protocol

Please refer to the new architectural design documentation for some background details. [Architectural design](http://omf.mytestbed.net/projects/omf/wiki/Architectural_Foundation)

## Abstract class

The abstract class OmfRc::ResourceProxy::Abstract is capturing all the logics regarding resource hierarchy, communications to pubsub system and methods to create, configure, request and release resources. Please note that the actual functionality of the resources are defined in proxy modules.

[OmfRc::ResourceProxy::AbstractResource](../../OmfRc/ResourceProxy/AbstractResource)

## Resource proxy utility

To avoid overloading these modules, we can refactor some of the common features into utility modules. These modules basically provide a mapping between properties and underline system application. Take the example of iw utility module implementation here: *(Refer to DSL section for syntax details)*

    require 'hashie'

    module OmfRc::Util::Iw
      include OmfRc::ResourceProxyDSL

      OmfCommon::Command.execute("iw help").chomp.gsub(/^\t/, '').split("\n").map {|v| v.match(/[phy|dev] <.+> set (\w+) .*/) && $1 }.compact.uniq.each do |p|
        register_configure p do |resource, value|
          OmfCommon::Command.execute("#{IW_CMD} #{resource.hrn} set #{p} #{value}")
        end
      end

      register_request :link do |resource|
        known_properties = Hashie::Mash.new

        OmfCommon::Command.execute("iw #{resource.hrn} link").chomp.gsub(/^\t/, '').split("\n").drop(1).each do |v|
          v.match(/^(.+):\W*(.+)$/).tap do |m|
            m && known_properties[m[1].downcase.gsub(/\W+/, '_')] = m[2].gsub(/^\W+/, '')
          end
        end

        known_properties
      end
    end

Take the example of the new generic wifi proxy module, we want to configure some wireless related properties (iw), and to load certain drivers/modules (mod). Since we already have these utility modules defined, all we need to do is to simply include these in the wifi module.


    module OmfRc::ResourceProxy::Wifi
      include OmfRc::ResourceProxyDSL

      register_proxy :wifi

      utility :mod
      utility :iw
    end

## Resource Proxy module

A resource proxy module defines what functionality the resource could provide, for example, a resource proxy represents a physical machine can provide property of kernel version, cpu information etc.

As explained in the previous section, a proxy module might just simply include some utility modules, or it could register properties specifically to this resource proxy, or even define additional methods (_not recommended though_), the methods defined here will be available to the resource instance as well.

## Factory class

We can then use resource factory method to create a resource instance.

    OmfRc::ResourceFactory.new(:wifi)

This does following behind the scene

* Extend the instance with resource module named 'wifi' (_should be defined already_).
* If additional options provided for pubsub communicator, a communicator instance will be created and attached to this resource instance.
* If before_ready hook provided in the module, they will be executed.

For implementation details, refer to [OmfRc::ResourceFactory](../../OmfRc/ResourceFactory)
