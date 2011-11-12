#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
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
# = omfAddress.rb
#
# == Description
#
# This file implements a generic OMF Address
#
#
class OmfAddress

  @name = nil
  @expID = nil
  @sliceID = nil
  @domain = nil
  attr_accessor :name, :expID, :sliceID, :domain

  def initialize (opts)
    if opts
      if opts.kind_of?(Hash) 
        @name = opts[:name] || nil
        @expID = opts[:expID] || nil
        @sliceID = opts[:sliceID] || nil
        @domain = opts[:domain] || nil
      elsif opts.kind_of?(OmfAddress) 
        @name = opts.name
        @expID = opts.expID
        @sliceID = opts.sliceID
        @domain = opts.domain
      else
        raise "Cannot construct Address with unknown options "+
              "(type: '#{opts.class}')"
      end
    end
    return self
  end

  def to_s
    return "[name:'#{@name}', slice:'#{@sliceID}', "+
            "exp:'#{@expID}', domain:'#{@domain}']"
  end

  # Return the address as string.
  #
  # global - [bool = FALSE] If true, return a globally resolvable address, 
  #             otherwise one which is resolvable within the given domain
  
  def generate_address(global = false)
    raise unimplemented_method_exception("generate_address")
  end

  private

  def unimplemented_method_exception(method_name)
    "OmfAddress - Subclass '#{self.class}' must implement #{method_name}()"
  end
end

