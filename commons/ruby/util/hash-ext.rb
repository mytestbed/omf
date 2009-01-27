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
