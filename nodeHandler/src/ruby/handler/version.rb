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
# = version.rb
#
# == Description
#
# This file defines a class that holds application versions
#

#
# This class holds application versions
#
class Version

  VERSION_EL_NAME = "version"

  attr_reader :major, :minor, :revision

  #
  # Create a new Version object
  # 
  # - major = major number for this version
  # - mino = minor number for this version
  # - revision = revision number for this version
  #
  def initialize(major = 0, minor = 0, revision = 0)
    @major = major
    @minor = minor
    @revision = revision
  end

  #
  # Return the version definition as an XML element
  #
  # [Return] an XML element with the value of this Version object
  #
  def to_xml
    e = REXML::Element.new("version")
    e.add_element("major").text = major
    e.add_element("minor").text = minor
    e.add_element("revision").text = revision
    return e
  end

end

#
# This class is the mutable class for Version 
#
class MutableVersion < Version

  attr_writer :major, :minor, :revision

end
