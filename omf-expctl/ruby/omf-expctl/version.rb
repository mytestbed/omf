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
# = version.rb
#
# == Description
#
# This file defines the version of this application
#

module OMF
  module ExperimentController

    # Find the absolute path of this file
    myPath = __FILE__.split("/")
    myPath.delete_at(myPath.size - 1)
    EC_PATH = myPath.join("/")

    VERSION_MAJOR = 5
    VERSION_MINOR = 2
    # Revision number is taken from the Source Repository
    # Following de-facto convention, revision number is set by 
    # the packaging scripts. 
    # (Pkg script will create the REVISION file with the info from the
    # source repository, thus REVISION only exists in software installed
    # from a package. We use 'testing' when REVISION is not found)
    VERSION_REVISION = File.readable?("#{EC_PATH}/REVISION") ? File.new("#{EC_PATH}/REVISION").read().chomp("$").to_i : "testing"
    
    VERSION = "#{VERSION_MAJOR}.#{VERSION_MINOR}.#{VERSION_REVISION}"
    VERSION_STRING = "OMF Experiment Controller V #{VERSION}"
  end
end


