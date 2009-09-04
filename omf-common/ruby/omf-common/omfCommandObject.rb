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
	  
  def to_xml()
    msg = REXML::Document.new
    msg << REXML::Element.new("#{@type.to_s}")
    msg.root << REXML::Element.new("GROUP").add_text("#{@group}") if @group != nil
    msg.root << REXML::Element.new("ID").add_text("#{@procID}") if @procID != nil
    msg.root << REXML::Element.new("PATH").add_text("#{@path}") if @path != nil
    msg.root << REXML::Element.new("ARGSLINE").add_text("#{@cmdLineArgs.join(" ")}") if @cmdLineArgs != nil
    # Build the <ENV> element
    if !@env.empty? 
      line = ""
      @env.each { |k,v|
        line << "#{k.to_s}=#{v.to_s} "  
      }
      msg.root << REXML::Element.new("ENV").add_text("#{line}")
    end
    # Build the <OML_CONFIG> element
    if @omlConfig != nil
      el = REXML::Element.new("OML_CONFIG")
      el.add_element(@omlConfig)
      msg.root << el
    end

    info "TDEBUG - TO_XML - #{msg.to_s}"
    return msg
  end

  def init_from_xml(xmlDoc)

    @type = xmlDoc.expanded_name
    xmlDoc.each_element("ID") { |e| @procID = e.text }
    xmlDoc.each_element("GROUP") { |e| @group = e.text }
    xmlDoc.each_element("PATH") { |e| @path = e.text }
    xmlDoc.each_element("ARGSLINE") { |e| @cmdLineArgs = e.text }
    xmlDoc.each_element("ENV") { |e| @env = e.text }

    xmlDoc.each_element("OML_CONFIG") { |config|
      configPath = nil
      config.each_element("omlc") { |omlc|
        configPath = "/tmp/#{omlc.attributes['exp_id']}-#{@procID}.xml"
      }
      f = File.new(configPath, "w+")
      info "TDEBUG - ToFILE - #{config.to_s}"
      config.each_element {|el|
        f << el.to_s
        info "TDEBUG - writing - #{el.to_s}"
      }
      f.close
      @env << " OML_CONFIG=#{configPath} "
    }
  
  end

end
