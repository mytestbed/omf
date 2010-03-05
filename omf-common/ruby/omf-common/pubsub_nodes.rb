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
# = pubsub_nodes.rb
#
# == Description
#
# This file defines the structure of the XMPP PubSub nodes used by OMF.
#

module OmfPubSubNodes
  DOMAIN = "OMF"
  RESOURCE = "resources"
  SYSTEM = "system"

  def slice_node(slice)
    "/#{DOMAIN}/#{slice}"
  end

  def experiment_node(slice, experiment)
    "#{slice_node(slice)}/#{experiment}"
  end

  def slice_resources_node(slice, resource = nil)
    if resource == nil
      "#{slice_node(slice)}/#{RESOURCE}"
    else
      "#{resources_node(slice)}/#{resource}"
    end
  end

  def system_node(resource = nil)
    if resource == nil
      "/#{DOMAIN}/#{SYSTEM}"
    else
      "#{system_node}/#{resource}"
    end
  end

  def system_node?(node_name)
    if node_name =~ /#{system_node}\/(.*)/ then
      $1
    else
      nil
    end
  end
end
