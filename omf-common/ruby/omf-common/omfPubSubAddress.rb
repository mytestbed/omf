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
# This file implements a specific OMF PubSub Address
#
#
require 'omf-common/omfAddress'

class OmfPubSubAddress < OmfAddress

  # Names for constant PubSub nodes
  PUBSUB_ROOT = "OMF"
  RESOURCE = "resources"
  SYSTEM = "system"

  def generate_address
    node = ""
    if @sliceID && @expID 
      return experiment_node(@sliceID, @expID, @name)
    elsif @sliceID 
      return resource_node(@sliceID, @name)
    elsif @name
      return system_node(@name)
    else
      raise "OmfPubSubAddress - Cannot generate pubsub node from address "
            +"'#{self.to_s}'"
    end
  end

  private

  def slice_node(slice)
    "/#{PUBSUB_ROOT}/#{slice}"
  end

  def experiment_node(slice, experiment, name = nil)
    return "#{slice_node(slice)}/#{experiment}/#{name}" if name
    return "#{slice_node(slice)}/#{experiment}"
  end

  def resource_node(slice, resource = nil)
    return "#{resource_node(slice)}/#{resource}" if resource
    return "#{slice_node(slice)}/#{RESOURCE}"
  end

  def system_node(resource = nil)
    return "#{system_node}/#{resource}" if resource
    return "/#{PUBSUB_ROOT}/#{SYSTEM}"
  end

  def system_node?(node_name)
    if node_name =~ /#{system_node}\/(.*)/ then
      $1
    else
      nil
    end
  end

end

