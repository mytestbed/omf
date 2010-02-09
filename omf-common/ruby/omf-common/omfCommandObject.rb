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
require 'rexml/parent.rb'
require 'rexml/document.rb'
require 'rexml/element.rb'

#
# A class implementing a Command Object (see the Command design pattern)
#
class OmfCommandObject 

  def [](key)
    return @attributs[key.upcase]
  end

  def method_missing(name, *args, &blocks)
    method = name.to_s.upcase
    if method[-1,1] == "="
      key = method[0..-2]
      @attributes[key.to_sym] = args[0]
    else
      return @attributes[name.to_s.upcase.to_sym]
    end
  end

  # The type of this Command Object (e.g. 'EXECUTE')
  #attr_accessor :type

  # The destination or group to which this Command Object is addressed to (optional, e.g. 'the_senders')
  #attr_accessor :target

  # The ID of the experiment for this Command Object (optional, e.g. 'myExp123')
  #attr_accessor :expID

  # The Name of the desired disk image on a resource receiving this Command Object (optional)
  #attr_accessor :image

  # The message conveyed by this Command Object (optional)
  #attr_accessor :message

  # The command line associated this Command Object (optional)
  #attr_accessor :cmd

  # The list of aliases for the resource sending this Command Object (optional)
  #attr_accessor :alias

  # The value associated with this Command Object (optional)
  #attr_accessor :value

  # The MC Address associated with this Command Object (optional)
  #attr_accessor :address

  # The MC Port associated with this Command Object (optional)
  #attr_accessor :port

  # The disk device associated with this Command Object (optional)
  #attr_accessor :disk

  # The name of the package or archive associated with this Command Object (optional)
  #attr_accessor :package

  # The ID of the application for this Command Object (optional, e.g. 'otg2')
  #attr_accessor :appID

  # The Environment to set for this Command Object (optional)
  #attr_accessor :env

  # The Path where the application for this EXECUTE Command Object is located (optional)
  # The Resource Path (XPath) associated with this CONFIGURE Command Object (optional)
  #attr_accessor :path

  # The command line arguments of the application for this Command Object (optional)
  #attr_accessor :cmdLineArgs

  # The XML definition for the OML configuration of the application for this Command Object (optional)
  #attr_accessor :omlConfig

  def initialize (initValue)
    @attributes = Hash.new
    if initValue.kind_of?(String) || initValue.kind_of?(Symbol)
      @attributes[:CMDTYPE] = initValue
    elsif initValue.kind_of?(REXML::Parent)
      init_from_xml(initValue)
    else
      raise "Trying to create a OmfCommandObject with unknown initial value (type: '#{initValue.class}')"
    end
  end
	  
  #
  # Return the XML representation for this Command Object
  # An example of a returned XML is: 
  #
  # <EXECUTE>
  #   <TARGET>source</TARGET>
  #   <PROCID>test_app_otg2</ID>
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
    msg << REXML::Element.new("#{@attributes[:CMDTYPE].to_s}")
    @attributes.each { |k,v|
      if (k == :OMLCONFIG) && (v != nil)
        el = REXML::Element.new("#{k.to_s.upcase}")
        el.add_element(v)
        msg.root << el
      elsif k != :CMDTYPE
        msg.root << REXML::Element.new("#{k.to_s.upcase}").add_text("#{v}") if v != nil
      end
    }
    return msg
    # Build the <ENV> child element
    #if (@env != nil) && (!@env.empty?) 
    #  line = ""
    #  @env.each { |k,v|
    #    line << "#{k.to_s}=#{v.to_s} "  
    #  }
    #  msg.root << REXML::Element.new("ENV").add_text("#{line}")
    #end
    # Build the <OML_CONFIG> child element
    #if @omlConfig != nil
    #  el = REXML::Element.new("OML_CONFIG")
    #  el.add_element(@omlConfig)
    #  msg.root << el
    #end
  end

  def to_s
    return to_xml.to_s
  end

  #
  # Create a new Command Object from a valid XML representation
  #
  # - xmlDoc = an xml document (REXML::Document) object 
  #
  def init_from_xml(xmlDoc)
    @attributes[:CMDTYPE] = xmlDoc.expanded_name.to_sym
    xmlDoc.each_element { |e| 
      if e.expanded_name.upcase.to_sym == :OMLCONFIG
        @attributes[e.expanded_name.upcase.to_sym] = e
      else
        @attributes[e.expanded_name.upcase.to_sym] = e.text
      end
    }

    # Dump the XML description of the OML configuration into a file
    #xmlDoc.each_element("OML_CONFIG") { |config|
    #  configPath = nil
    #  config.each_element("omlc") { |omlc|
    #    configPath = "/tmp/#{omlc.attributes['exp_id']}-#{@appID}.xml"
    #  }
    #  f = File.new(configPath, "w+")
    #  config.each_element {|el|
    #    f << el.to_s
    #  }
    #  f.close
    #  # Set the OML_CONFIG environment with the path to the XML file
    #  @env << " OML_CONFIG=#{configPath} "
    #}
  end

end
