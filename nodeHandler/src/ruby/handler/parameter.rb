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
# = parameter.rb
#
# == Description
#
# This file defines the Parameter class 
#
#

#
# This class describes a Parameter
#
class Parameter

  attr_reader :id, :name, :description, :defaultValue

  #
  # Create a new Parameter instance
  #
  # - id = parameter identifier
  # - name = name for this parameter
  # - description = short description of this parameter
  # - defaultValue = optional, a defautl value for this parameter (default=nil)
  #
  def initialize(id, name, description, defaultValue = nil)
    @id = id
    @name = name != nil ? name : id
    @description = description
    @defaultValue = defaultValue
  end

  #
  # Return the definition of this Parameter as an XML element
  #
  # [Return] an XML element with the definition of this Parameter
  #
  def to_xml
    a = REXML::Element.new("parameter")
    a.add_attribute("id", id)
    a.add_attribute("name", name)
    if (description != nil)
      a.add_element("description").text = description
    end
    if (defaultValue != nil)
      a.add_element("default").text = defaultValue
    end
    return a
  end

end
