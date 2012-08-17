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
require 'omf-common/communicator/omfMessage'

#
# A class implementing an OMF Command Object 
#
class OmfPubSubMessage < OmfMessage 

  #
  # Return the XML representation for this Command Object
  # An example of a returned XML is:
  #
  # <EXECUTE>
  #   <TARGET>source</TARGET>
  #   <APPID>test_app_otg2</APPID>
  #   <PATH>/usr/bin/otg2</PATH>
  #   <ARGSLINE>
  #     --udp:dst_host 192.168.0.3 --udp:local_host 192.168.0.2
  #   </ARGSLINE>
  #   <ENV>
  #     OML_SERVER=tcp:10.0.0.200:3003 OML_EXP_ID=sandbox1 OML_NAME=source 
  #   </ENV>
  #   <OML_CONFIG>
  #     <omlc id='source' exp_id='sandbox1_2009_09_07_09_52_10'>
  #     <collect url='tcp:10.0.0.200:3003'>
  #       <mp name='udp_out' interval='5' />
  #     </collect>
  #     </omlc>
  #   </OML_CONFIG>
  # </EXECUTE>
  #
  # [Return] an XML element
  #
  def serialize
    msg = REXML::Document.new
    # Set the Type of the XML to return
    msg << REXML::Element.new("#{@attributes[:CMDTYPE].to_s}")
    # For each attribute of this Command Object, create the required XML element
    @attributes.each { |k,v|
      # If this attribute value is an XML Element, then add it as is to the 
      # resulting XML element
      if (v != nil) && (v.kind_of?(REXML::Element))
        el = REXML::Element.new("#{k.to_s.upcase}")
        el.add_element(v)
        msg.root << el
      # For all other attributes, add the value as a text to the XML to return
      elsif k != :CMDTYPE && v != nil
        msg.root << REXML::Element.new("#{k.to_s.upcase}").add_text("#{v}") 
      end
    }
    return msg
  end

  #
  # Create a new Command Object from a valid XML representation
  #
  # - xmlDoc = an xml document (REXML::Document) object
  #
  def create_from(xmlDoc)
    begin
      # Set the Type
      @attributes[:CMDTYPE] = xmlDoc.expanded_name.to_sym
      # Parse the XML object
      xmlDoc.each_element { |e|
        # For the OMLCONFIG tag, add the XML value to this Command Object
        if e.expanded_name.upcase.to_sym == :OMLCONFIG
          @attributes[e.expanded_name.upcase.to_sym] = e
        # For the other tags, add the text value to this Command Object
        else
          @attributes[e.expanded_name.upcase.to_sym] = e.text
        end
      }
    rescue Exception => ex
      raise "Failed to create new OmfCommandObject from XML"
    end
  end

  #
  # Return a String representation of the XML tree describing this
  # Command Object.
  #
  # [Return] a String
  #
  def to_s
    return serialize.to_s
  end

  # NOTE: 
  #
  # This is a list of currently used attributes, depending on the command type
  #
  # cmdType - The type of this Command (e.g. 'EXECUTE')
  # target - The destination or group to which this Command is addressed to 
  #          (e.g. 'the_senders')
  # expID - The ID of the experiment for this Command (e.g. 'myExp123')
  # image - The Name of the desired disk image on a resource receiving this Command 
  # message - The message conveyed by this Command 
  # cmd - The command line associated this Command 
  # name - The list of aliases for the resource sending this Command 
  # value - The value associated with this Command 
  # address - The MC Address associated with this Command 
  # port - The MC Port associated with this Command 
  # disk - The disk device associated with this Command 
  # package - The name of the package or archive associated with this Command 
  # appID - The ID of the application for this Command 
  # env - The Environment to set for this Command 
  # path - The Path to the application for this EXECUTE Command 
  # path - The Resource Path (XPath) associated with this CONFIGURE Command 
  # cmdLineArgs - The command line arguments of the application for this Command 
  # omlConfig - The XML definition for the OML configuration of the application for this Command 
end
