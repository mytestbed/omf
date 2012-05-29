# Resource Proxy

## Abstract class

The abstract class OmfRc::ResourceProxy::Abstract is capturing all the logics regarding resource hierarchy, validation, statemachine and methods to create, configure, and destroy resources.

A important attribute of resource proxy is 'type', when a new resource instance created, it will extend the object with a pre-defined module with the same name.

## Resource Proxy module

Since we treat everything as a resource, a resource proxy module defines what functionality the resource can provide, i.e. what it does, instead of what it is.

Each module should define two methods:

* configure_property(property, value)
* request_property(property)

## Resource Proxy Utility

To avoid overloading these modules, we can refactor some of the common features into utility modules. These modules basically provide a mapping between properties and underline system application. E.g. resource.request_property(:driver_bob) will be parsed to is drive/module bob loaded by executing lsmod command.

Take the example of the new generic wifi proxy module, we want to configure certain interface properties (ifconfig), some wireless related properties (iw), and to load certain drivers/modules (mod). Since we already have these utility modules defined, all we need to do is to simply include these in the wifi module.

## What about ResourceProxyFactory

We do not need a factory class per se, we can always start with a root resource (probably virtual) by create a resource with type 'abstract'. Then create new resources by giving a proper type.

## Is 'type' enough to differentiate resources?

If a module definition for certain type is not meeting the requirement, but additional features have been implemented in one of the util modules, we could provide a way to specify and dynamically include additional modules, without creating a new module file.

