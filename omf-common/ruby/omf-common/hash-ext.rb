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
# Add some functions to the Hash class
#
class Hash

  # Adds the contents of 'other to this hash, overwriting entries
  # with duplicate keys with those from 'other'. If hash entry (value)
  # is a hash itself, recurse into it.
  #
  def merge_deep!(other)
    other.each do |k, v|
      if (v.instance_of?(Hash) && (sv = self[k]).instance_of?(Hash))
  sv.merge_deep!(v)
      else
  self[k] = v
      end
    end
    self
  end
end

if __FILE__ == $0
  base = {:a => {:b => 2, :d => 4}, :foo => 1}
  p base
  mix = {:a => {:b => 22, :c => 3}}
  p base.merge_deep!(mix)
end
