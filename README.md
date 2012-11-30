# OMF

[![Build Status](https://secure.travis-ci.org/mytestbed/omf.png)](http://travis-ci.org/mytestbed/omf)

## Important

We are currently working on this towards our new version 6 release. These pre-release packages are demonstrating the new system design, protocol and API, and for now, especially, the new resource controller structure and API for reviewing. The code, protocol, and API will be continuously evolving and if you have any suggestion regarding the design or implementation, feel free to [create a new issue](https://github.com/mytestbed/omf/issues).

_If are looking for the current 5.4 stable release, please go to our official website and follow the [installation guide](https://omf.mytestbed.net/projects/omf/wiki/Installation)_

## Introduction to OMF

OMF is a framework for controlling, instrumenting, and managing experimental platforms (testbeds).

* Researchers use OMF to describe, instrument, and execute their experiments.

* Testbed providers use OMF to make their resources discoverable, control access to them, optimise their utilisation through virtualisation, and federation with other testbeds.

Please visit our official website [mytestbed.net](https://www.mytestbed.net) for more information.

## Documentation

Official source code documentation can be found here.

http://mytestbed.net/doc/omf/

For full documentation regarding the design of OMF version 6, please visit our [design documentation](http://omf.mytestbed.net/projects/omf/wiki/Architectural_Foundation)

## Release notes

[6 Beta](http://mytestbed.net/projects/omf/wiki/OMF6Beta)

[6 Alpha](http://mytestbed.net/projects/omf/wiki/OMF6Alpha)

## Installation

_If you have Eventmachine 1.0.0 installed on your system and you noticed some delay behaviour, please uninstall it and use version 0.12.x instead._

### I do not have git, ruby, or gem ...

Please check and install these additional dependencies for your environment:

{file:doc/INSTALLATION.mkd Detailed installation guide}

### From rubygems

In OMF 6, we switched to the GEM system to release packages.

To install OMF Resource Controller (RC), simple do (--pre indicates pre-release):

    gem install omf_rc --pre --no-ri --no-rdoc

For OMF Experiment Controller (EC):

    gem install omf_ec --pre --no-ri --no-rdoc

_We are building and testing against Ruby version 1.9.2 and 1.9.3, means we are dropping support for Ruby 1.8._

[RVM (ruby version manageer)](https://rvm.io/) is strongly recommended if your OS release doesn't provide these ruby versions.

### From repository

You could also build and install packages using the latest source from git repository:

    git clone https://github.com/mytestbed/omf.git

Then inside the repository directory, type:

    rake

This will install all the necessary gems, build omf gems, and run the test files.

_Some components are linked in omf main repository as git submodules, if you want to use them, simply issue these commands inside the newly cloned repository:_

    git submodule init
    git submodule update

## XMPP server installation and configuration

We recommend Openfire XMPP server. [Installation notes for Openfire](https://omf.mytestbed.net/projects/omf/wiki/Installation_Guide_54#Configuring-XMPP)

### In-band registration

Enable in-band registration support (XEP-0077) on the XMPP server if you want to automatically create the users by the time of connection.

### Anonymous authentication

If your XMPP server has anonymous authentication enabled, you might not have permissions to create pub-sub topics when connected anonymously, to avoid the trouble, please turn off the anonymous authentication mode.

### Multiple subscriptions

To avoid duplicated subscription to the same topic, thus reduce the volume of messages, we recommend turn multiple subscriptions feature off.

Inside Openfire system properties panel, add

    Property Name: xmpp.pubsub.multiple-subscriptions
    Property Value: false

## New messaging protocol

[OMF messaging protocol](http://omf.mytestbed.net/projects/omf/wiki/ArchitecturalFoundation2ProtocolInteractions)

## Contributing

Contribute to OMF project? Please refer to this document for some notes:

{file:doc/CONTRIBUTING.mkd}

## OMF resource controller system

One of the biggest changes we are trying to make in version 6 resource controller system is to focus on the core features, and instead of trying to implement all the functionalities and hardware support, we want to provide an abstract entity acts as the proxy, processing the resource related messages based on the [new messaging protocol](http://omf.mytestbed.net/projects/omf/wiki/ArchitecturalFoundation2ProtocolInteractions), and decides what type of the actions to perform according to the operation defined by the message and constrained by the proxy's capabilities which could be easily defined and extended by the resource providers.

In our design, the clients interact with the resource proxies purely via pubsub messages, they publish certain operation (create, request, configure, and release) messages to the pubsub topics, and subscribe to the nodes for inform messages published by the resource proxies based on the outcome of the these requested operations. The resource proxy instances are actually doing the same, but the opposite, they are subscribing to the pubsub system, react when new operation messages appeared by calling the internal methods corresponding to the content of the operation messages. For example, when a request message contains XML entity property 'speed' received, the resource proxy will try to call method 'request\_speed' (it is a naming convention, method name request\_property\_name is for request messages, and configure\_property\_name is for configure messages.)

Since the base abstract resource proxy doesn't have request\_speed method defined, we need to extend it by implementing a resource proxy definition file, which contains the definition of request\_speed functionality. The resource proxy definition is a mixin module, conceptually represents a type of resource it needs to handle. These modules could define a series of functionalities they could support, including:

* Register a module to be used by the resource controller
* Properties can be requested
* Properties can be configured
* Operations should be performed at certain stage, e.g. before resource is ready to use, or before resource is set to be released.

When a new instance of resource proxy is being created, such mixin modules can be used to extend the resource proxy instance. By naming convention, creating an instance of resource proxy with type ':alpha', will result the resource proxy instance extended using mixin resource proxy module 'Alpha'.

This little tutorial will give a brief example on how to implement the resource proxy definitions.

### {file:doc/RESOURCE\_PROXY.mkd Example: implement your own resource proxy files}

## More RC tutorials

### {file:doc/APPLICATION\_PROXY.mkd How to use the Application Proxy}
### {file:doc/PROXY\_INSTRUMENTATION.mkd Instrumentation of a Resource Proxy}

## License & Copyright

Copyright (c) 2006-2012 National ICT Australia (NICTA), Australia

Copyright (c) 2004-2009 WINLAB, Rutgers University, USA

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal
in the software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sub-license, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
