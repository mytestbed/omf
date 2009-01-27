#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 WINLAB, Rutgers University, USA
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
# = antenna.rb
#
# == Description
#
# This class represents an antenna. An antenna is associated with a
# SignalGenerator and a SpectrumAnalyzer
#
require 'util/mobject'
require 'net/http'

#
# This class represents an antenna. An antenna is associated with a
# SignalGenerator and a SpectrumAnalyzer
#
class Antenna < MObject

  @@antennas = Hash.new

  #
  # Access a particular 'Antenna' instance
  #
  def Antenna.[] (x, y, precision = nil)
    key = "#{x}@#{y}"

    # right now, we just have ONE
    key = "1@1"
    return @@antennas[key]
  end

  def Antenna.each(&block)
    @@antennas.each_value &block
  end

  #
  # Create an 'Antenna' at a specific location
  # If no node exists, then create a new one.
  #
  # - x = Location's x coordinate
  # - y = Location's x coordinate
  #
  def Antenna.create(x, y)
    key = "#{x}@#{y}"

    # right now, we just have ONE
    key = "1@1"
    a = Antenna.new(key)
    @@antennas[key] = a
    return a
  end

  def initialize(name)
    @signal = SignalGenerator.new("instrument1", "1")
  end

  #
  # Execute 'block' on a given Signal Generator
  #
  # - &block = the block to execute
  #
  def signal(&block)
    if block != nil
      block.call(@signal)
    end
    @signal
  end

end

#
# This class controls a specific SignalGenerator
#
class SignalGenerator < MObject

  def initialize(name, inst_id)
    @name = name
    @inst_id = inst_id
    @url = "http://instrument#{@inst_id}.orbit-lab.org:8001/esg?instrument_id=#{inst_id}"
  end

  attr_reader :bandwidth, :channel, :power, :on

  #
  # Set the bandwidth
  # - bandwidth = value to use 
  #
  def bandwidth=(bandwidth)
    bandwidth = getValue(bandwidth) { |v|
      self.bandwidth = v
    }

    if (@bandwidth == bandwidth)
      return
    end

    url = "#{@url}&signal_type=noise&bandwidth=#{bandwidth}"
    NodeHandler.service_call(url, "Can't set bandwidth to #{@bandwidth}")
    @bandwidth = bandwidth
  end

  #
  # Set the channel
  # - channel = value to use 
  #
  def channel=(channel)
    channel = getValue(channel) { |v|
      self.channel = v
    }

    if (@channel == channel)
      return
    end

    url = "#{@url}&signal_type=noise&channel=#{channel}"
    NodeHandler.service_call(url, "Can't set channel to #{@channel}")
    @channel = channel
  end

  #
  # Set the power
  # - power = value to use 
  #
  def power=(power)
    power = getValue(power) { |v|
      self.power = v
    }

    if (@power == power)
      return
    end

    url = "#{@url}&signal_type=noise&power=#{power}"
    NodeHandler.service_call(url, "Can't set power to #{@power}")
    @power = power
  end

  #
  # Switch ON the Signal Generator
  #
  def on()
    if (@on)
      return
    end

    url = "#{@url}&command=start"
    NodeHandler.service_call(url, "Can't switch generator on")
    #info("Switched on signal generator #{inst_id} bw: #{@bandwidth} ch: #{@channel} pw: #{@power}")
    info("Switched on signal generator bw: #{@bandwidth} ch: #{@channel} pw: #{@power}")
    @on = true
  end

  #
  # Switch OFF the Signal Generator
  #
  def off()
    if (! @on)
      return
    end

    url = "#{@url}&command=stop"
    NodeHandler.service_call(url, "Can't switch generator off")
    #info("Switched off signal generator #{inst_id}")
    info("Switched off signal generator")
    @on = false
  end

  private

  # 
  # Returns the value of a given experiment property
  #
  def getValue(prop, &onChange)
    if prop.kind_of?(ExperimentProperty)
      prop.onChange(&onChange)
      prop = prop.value
    end
    prop
  end

end

# Right now, we just have one antenna which works for everything
Antenna.create(1,1)

if $0 == __FILE__

  MObject.initLog('antenna')

  # Right now, we just have one antenna which works for everything
  Antenna.create(1,1)

  MObject.info("Antenna Testharness")

  Antenna[1, 2].signal {|s|
    s.bandwidth = 20
    s.channel = 3
    s.power = -18
    s.on
  }

  Kernel.sleep 20

  Antenna[1, 2].signal.off
end

