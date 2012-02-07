#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2010 WINLAB, Rutgers University, USA
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
# = omfCommandObject.rb
#
# == Description
#
# This file implements the common Command Object that OMF entities use to
# exchance messages between each other
#
require 'rexml/parent.rb'
require 'rexml/document.rb'
require 'rexml/element.rb'

#
# A class implementing an OMF Command Object 
#
class OmfMessage

  attr_reader :attributes

  #
  # Return the value of an attribute of this Command Object
  #
  # - key = the name of the attribute
  #
  # [Return] the value of the attribute
  #
  def [](key)
    return @attributes[key.to_s.upcase.to_sym]
  end

  #
  # Set the value of an attribute of this Command Object
  #
  # - key = the name of the attribute
  # - value = the value of the attribute
  #
  def []=(key, value)
    @attributes[key.to_s.upcase.to_sym] = value
  end

  #
  # Return or Set the value of an attribute of this Command Object
  # But do so via the use of method_missing, so one can query or set
  # the attribute using a 'dot' syntax.
  # E.g. myCmd.myAttribute = 123
  # E.g. var = myCmd.myAttribute
  # A list of currently used attributes can be found at the end of
  # this file
  #
  # - name = the name of the attribut
  #
  # [Return] the value of the attribute, if called as a query
  #
  def method_missing(name, *args, &blocks)
    method = name.to_s.upcase
    if method[-1,1] == "="
      key = method[0..-2]
      @attributes[key.to_sym] = args[0]
    else
      return @attributes[name.to_s.upcase.to_sym]
    end
  end

  #
  # Create a new Command Object
  #
  # - initOptions = Hash of attribute values.
  #
  #  [Return] a new Command Object
  #
  def initialize(initOptions = {})
    # Create a new Hash to hold the attributes of this Command Object
    @attributes = Hash.new
    
    unless initOptions.kind_of?(Hash) 
      raise "Cannot create a OmfMessage! Unknown initial options "+
            "(type: '#{initOptions.class}')"
    end

    initOptions.each do |k,v|
      self[k] = v
      #kSym = k.to_s.upcase.to_sym # normalize keys
      #@attributes[kSym] = v
    end
  end

  def each(&block)
    @attributes.each { |k,v|
      block.call(k,v)
    }
  end

  def merge(another)
    if another.kind_of?(self.class) || another.kind_of?(Hash)
      another.each { |attr, val|
	       @attributes[attr] = val if @attributes[attr] == nil
      }
    else
      raise "Cannot merge with another message! Unknown message type "+
            "(type: '#{another.class}')"
    end
  end

  def serialize 
    raise unimplemented_method_exception("serialize")
  end

  def create_from 
    raise unimplemented_method_exception("create_from")
  end

  private

  def unimplemented_method_exception(method_name)
    "OmfMessage - Subclass '#{self.class}' must implement #{method_name}()"
  end

end
