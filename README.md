# OMF

[![Build Status](https://secure.travis-ci.org/mytestbed/omf.png)](http://travis-ci.org/mytestbed/omf)

## Introduction

OMF is a framework for controlling, instrumenting, and managing experimental platforms (testbeds).

* Researchers use OMF to describe, instrument, and execute their experiments.

* Testbed providers use OMF to make their resources discoverable, control access to them, optimise their utilisation through virtualisation, and federation with other testbeds.

[More information](https://omf.mytestbed.net/projects/omf/wiki/Introduction)

## Official website

[http://www.mytestbed.net/](http://www.mytestbed.net/)

## Documentation

[http://rubydoc.info/github/mytestbed/omf/frames](http://rubydoc.info/github/mytestbed/omf/frames)

## Installation

OMF components are released as Ruby Gems.

To install OMF RC, simple type:

    gem install omf_rc --no-ri --no-rdoc

For pre-release gems, simply use --pre option:

    gem install omf_rc --pre --no-ri --no-rdoc

Common library omf\_common will be included automatically by RC.

To only install OMF Common library:

    gem install omf_common --no-ri --no-rdoc

## Extend OMF

We sincerely welcome all contributions to OMF. Simply fork our project via github, and send us pull requests whenever you are ready.

## Supported Ruby versions

We are building and testing against Ruby version 1.9.2 and 1.9.3, means we are dropping support for Ruby 1.8.

## Components

### Common

Common library shared among OMF applications

* PubSub communication, with default XMPP implementation, using Blather gem.
* OMF message class for authoring and parsing messages based on new OMF messaging protocol.
* RelaxNG schema for messaging protocol definition and validation.

### Resource Controller

* Resource proxy API for designing resource functionalities.
* Abstract resource provides common features required for all resources.

## OMF 6 design documentation

For full documentation regarding design of OMF version 6, please visit our [official documentation](http://omf.mytestbed.net/projects/omf/wiki/Architectural_Foundation)

## License & Copyright

Copyright (c) 2006-2012 National ICT Australia (NICTA), Australia

Copyright (c) 2004-2009 WINLAB, Rutgers University, USA

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal
in the software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sub-license, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
