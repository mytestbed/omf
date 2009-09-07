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
#
require 'omf-common/mobject'

#
# A class implementing a Command Object (see the Command design pattern)
#
class OmfCommandObject < MObject

  # The type of this Command Object (e.g. 'EXECUTE')
  attr_accessor :type

  # The group to which this Command Object is addressed to (optional, e.g. 'the_senders')
  attr_accessor :group

  # The ID of the application for this Command Object (optional, e.g. 'otg2')
  attr_accessor :procID

  # The Environment to set for this Command Object (optional)
  attr_accessor :env

  # The Path where the application for this Command Object is located (optional)
  attr_accessor :path

  # The command line arguments of the application for this Command Object (optional)
  attr_accessor :cmdLineArgs

  # The XML definition for the OML configuration of the application for this Command Object (optional)
  attr_accessor :omlConfig

  def initialize (initValue)
    @group = nil
    @procID = nil
    @env = nil
    @path = nil
    @cmdLineArgs = nil
    @omlConfig = nil
    if initValue.kind_of?(String) || initValue.kind_of?(Symbol)
      @type = initValue
    elsif initValue.kind_of?(REXML::Parent)
      init_from_xml(initValue)
    else
      raise "Trying to create a OmfCommandObject with unknown initial value"
    end
  end
	  
  #
  # Return the XML representation for this Command Object
  # An example of a returned XML is: 
  #
  # <EXECUTE>
  #   <GROUP>source</GROUP>
  #   <ID>test_app_otg2</ID>
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
    msg << REXML::Element.new("#{@type.to_s}")
    msg.root << REXML::Element.new("GROUP").add_text("#{@group}") if @group != nil
    msg.root << REXML::Element.new("ID").add_text("#{@procID}") if @procID != nil
    msg.root << REXML::Element.new("PATH").add_text("#{@path}") if @path != nil
    msg.root << REXML::Element.new("ARGSLINE").add_text("#{@cmdLineArgs.join(" ")}") if @cmdLineArgs != nil
    # Build the <ENV> child element
    if !@env.empty? 
      line = ""
      @env.each { |k,v|
        line << "#{k.to_s}=#{v.to_s} "  
      }
      msg.root << REXML::Element.new("ENV").add_text("#{line}")
    end
    # Build the <OML_CONFIG> child element
    if @omlConfig != nil
      el = REXML::Element.new("OML_CONFIG")
      el.add_element(@omlConfig)
      msg.root << el
    end
    return msg
  end

  #
  # Create a new Command Object from a valid XML representation
  #
  # - xmlDoc = an xml document (REXML::Document) object 
  #
  def init_from_xml(xmlDoc)
    @type = xmlDoc.expanded_name
    xmlDoc.each_element("ID") { |e| @procID = e.text }
    xmlDoc.each_element("GROUP") { |e| @group = e.text }
    xmlDoc.each_element("PATH") { |e| @path = e.text }
    xmlDoc.each_element("ARGSLINE") { |e| @cmdLineArgs = e.text }
    xmlDoc.each_element("ENV") { |e| @env = e.text }
    # Dump the XML description of the OML configuration into a file
    xmlDoc.each_element("OML_CONFIG") { |config|
      configPath = nil
      config.each_element("omlc") { |omlc|
        configPath = "/tmp/#{omlc.attributes['exp_id']}-#{@procID}.xml"
      }
      f = File.new(configPath, "w+")
      config.each_element {|el|
        f << el.to_s
      }
      f.close
      # Set the OML_CONFIG environment with the path to the XML file
      @env << " OML_CONFIG=#{configPath} "
    }
  end

end
