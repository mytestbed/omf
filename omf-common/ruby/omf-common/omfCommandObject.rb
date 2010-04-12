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

#
# A class implementing an OMF Command Object 
#
class OmfCommandObject

  attr_reader :attributes

  # Valid commands for the EC
  EC_COMMANDS = Set.new [:EXECUTE, :KILL, :STDIN, :NOOP, 
	                :PM_INSTALL, :APT_INSTALL, :RPM_INSTALL, :RESET, 
                        :REBOOT, :MODPROBE, :CONFIGURE, :LOAD_IMAGE,
                        :SAVE_IMAGE, :LOAD_DATA, :SET_MACTABLE, :ALIAS,
                        :RESTART, :ENROLL, :EXIT]
  def isECCommand?
    return EC_COMMANDS.include?(@attributes[:CMDTYPE])
  end

  # Valid commands for the RC
  RC_COMMANDS = Set.new [:ENROLLED, :WRONG_IMAGE, :OK, :HB, :WARN, 
                        :APP_EVENT, :DEV_EVENT, :ERROR, :END_EXPERIMENT]
  def isRCCommand?
    return RC_COMMANDS.include?(@attributes[:CMDTYPE])
  end    

  # Valid commands for the Inventory AM
  INVENTORY_COMMANDS = Set.new [:XYZ]
  def isInventoryCommand?
    return INVENTORY_COMMANDS.include?(@attributes[:CMDTYPE])
  end    

  #
  # Return the value of an attribute of this Command Object
  # A list of currently used attributes can be found at the end of
  # this file
  #
  # - key = the name of the attribut
  #
  # [Return] the value of the attribute
  #
  def [](key)
    return @attributes[key.upcase]
  end

  #
  # Return or Set the value of an attribute of this Command Object
  # But do so via the use of method_missing, so one can query or set
  # the attribute using a 'dot' syntax.
  # E.g. myCmd.myAttribute = 123
  # E.g. var = myCmd.myAttribute
  # A list of currently used attributes can be found at the end of
  # this file
  #
  # - name = the name of the attribut
  #
  # [Return] the value of the attribute, if called as a query
  #
  def method_missing(name, *args, &blocks)
    method = name.to_s.upcase
    if method[-1,1] == "="
      key = method[0..-2]
      @attributes[key.to_sym] = args[0]
    else
      return @attributes[name.to_s.upcase.to_sym]
    end
  end

  #
  # Create a new Command Object
  #
  # - initValue = if a String or Symbol, then create an empty Command Object, with its
  #               command type set to the String/Symbol
  #               if an XML stanza, then create a new Command Object based on the
  #               XML description
  #
  #  [Return] a new Command Object
  #
  def initialize (initValue)
    # Create a new Hash to hold the attributes of this Command Object
    @attributes = Hash.new
    # Set the Command Type
    if initValue.kind_of?(String) || initValue.kind_of?(Symbol)
      @attributes[:CMDTYPE] = initValue
    # Or build a new Command Object from an XML stanza
    elsif initValue.kind_of?(REXML::Parent)
      init_from_xml(initValue)
    else
      raise "Cannot create a OmfCommandObject! Unknown initial value (type: '#{initValue.class}')"
    end
  end

  #
  # Return the XML representation for this Command Object
  # An example of a returned XML is:
  #
  # <EXECUTE>
  #   <TARGET>source</TARGET>
  #   <APPID>test_app_otg2</APPID>
  #   <PATH>/usr/bin/otg2</PATH>
  #   <ARGSLINE>--udp:dst_host 192.168.0.3 --udp:local_host 192.168.0.2</ARGSLINE>
  #   <ENV>OML_SERVER=tcp:10.0.0.200:3003 OML_EXP_ID=sandbox1 OML_NAME=source </ENV>
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
  def to_xml()
    msg = REXML::Document.new
    # Set the Type of the XML to return
    msg << REXML::Element.new("#{@attributes[:CMDTYPE].to_s}")
    # For each attribute of this Command Object, create the required XML element
    @attributes.each { |k,v|
      # For the OML Config attribute, add the value as an XML element to the XML to return
      if (k == :OMLCONFIG) && (v != nil)
        el = REXML::Element.new("#{k.to_s.upcase}")
        el.add_element(v)
        msg.root << el
      # For all other attributes, add the value as a text to the XML to return
      elsif k != :CMDTYPE
        msg.root << REXML::Element.new("#{k.to_s.upcase}").add_text("#{v}") if v != nil
      end
    }
    return msg
  end

  #
  # Create a new Command Object from a valid XML representation
  #
  # - xmlDoc = an xml document (REXML::Document) object
  #
  def init_from_xml(xmlDoc)
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
  end

  #
  # Return a String representation of the XML tree describing this
  # Command Object.
  #
  # [Return] a String
  #
  def to_s
    return to_xml.to_s
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
