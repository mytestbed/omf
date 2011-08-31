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
# == Description
#
# This file defines the version of this application
#

module OMF
  module Common

    VERSION_MAJOR = 5
    VERSION_MINOR = 4

    def self.MM_VERSION()
      return "#{VERSION_MAJOR}.#{VERSION_MINOR}"
    end

    #
    # Return the full version number for an OMF software
    #
    def self.VERSION(path)
      # Find the absolute path 
      myPath = path.split("/")
      myPath.delete_at(myPath.size - 1)
      absPath = myPath.join("/")
      # Revision number is taken from the Source Repository
      # Following de-facto convention, revision number is set by 
      # the packaging scripts. 
      # (Pkg script will create the REVISION file with the info from the
      # source repository, thus REVISION only exists in software installed
      # from a package. We use 'testing' when REVISION is not found)
      revision = File.readable?("#{absPath}/REVISION") ? File.new("#{absPath}/REVISION").read().chomp : "testing"
      version = "#{VERSION_MAJOR}.#{VERSION_MINOR} (git #{revision})"
      return version
    end
  end
end


