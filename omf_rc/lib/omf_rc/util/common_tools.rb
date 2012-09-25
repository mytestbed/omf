#
# Copyright (c) 2012 National ICT Australia (NICTA), Australia
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
# This module defines a Utility with some common work blocks that could be
# useful to any type of Resource Proxy (RP)
#
module OmfRc::Util::CommonTools
  include OmfRc::ResourceProxyDSL

  # This utility block logs an error/warn String S on the resource proxy side
  # and publish an INFORM message on the resources pubsub topic. This INFORM
  # message will have the type ERROR/WARN, and its 'reason' element set to the
  # String S
  #
  # @yieldparam [String] msg the error or warning message
  #
  %w(error warn).each do |type|
    work("log_inform_#{type}") do |res, msg|
      logger.send(type, msg)
      res.comm.publish(
        res.uid,
        OmfCommon::Message.inform(type.upcase) do |message|
          message.element('reason' , msg)
        end
      )
    end
  end

  # This utility block returns true if its given value parameter is a Boolean,
  # which in Ruby means that it is either of the class TrueClass or FalseClass
  #
  # @yieldparam [Object] obj the Object to test as Boolean
  #
  # [Boolean] true or fals
  #
  work('boolean?') do |res,obj|
    result = false
    result = true if obj.kind_of?(TrueClass) || obj.kind_of?(FalseClass)
    result
  end
end
