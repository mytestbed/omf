# Resource Proxy Plug-in

## Abstract class

The abstract class OmfRc::ResourceProxy::Abstract is capturing all the logics regarding resource hierarchy, validation, statemachine and methods to create, configure, and destroy resources.

A important attribute of resource proxy is 'type', when a new resource instance created, it will extend the object with a pre-defined module with the same name.

## Resource Proxy module

Since we treat everything as a resource, a resource proxy module defines what functionality the resource can provide, i.e. what it does, instead of what it is.

Each module should define two methods:

* configure_property(property, value)
* request_property(property)

