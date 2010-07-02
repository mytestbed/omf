#
# Copyright (c) 2010 National ICT Australia (NICTA), Australia
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
# = keyLocator.rb
#
# == Description
#
# Implements functions to locate and verify public and private SSL
# keys and serve them to other classes
#

require 'omf-common/mobject'

class KeyLocator
  @private_key_file = ""
  @public_key_dir = ""
  @authorized_keys = Array.new
  
  #
  # Create a new keyLocator
  #
  def initialize(private_key_file, public_key_dir)
    @private_key_file = private_key_file
    @public_key_dir = public_key_dir
    puts " INFO KeyLocator: Using private key '#{private_key_file}', using public keys in '#{public_key_dir}'"
    # check whether files exist
    # read files and check if keys are valid
    # add pubkeys into key array
    # ...
  end

end
