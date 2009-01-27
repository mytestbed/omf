#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 WINLAB, Rutgers University, USA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
# = exception.rb
#
# == Description
#
# This file defines a few exception class, which are used to control error handling
#

#
# This class defines an exception, which is called when an event
# may impede the progress of an experiment.
#
class ProgressException < RuntimeError
end

#
# This class defines an exception, which is called when a 
# grid service request failed 
#
class ServiceException < ProgressException

  attr :response, :message

  def initialize(response = nil, message = nil)
    @response = response
    @message = message
  end
end

#
# This class defines an exception, which is called when a 
# configuration task/event failed 
#
class ConfigException < RuntimeError
end

#
# This class defines an exception, which is called when a 
# resource-related task/event failed 
#
class ResourceException < RuntimeError
end

