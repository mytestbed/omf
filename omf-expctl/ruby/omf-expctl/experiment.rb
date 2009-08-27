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
# = experiment.rb
#
# == Description
#
# This class is the entry point for all experiments. It is
# is primarily used as a singleton
#

require 'omf-common/mobject'
require 'omf-expctl/traceState'
require 'optparse'

#
# This class is the entry point for all experiments. It is
# is primarily used as a singleton
#
class Experiment

  @@name = "UNKNOWN"  # name of experiment
#  @@expRoot = nil
  @@expPropsOverride = Hash.new  # from command line options
  @@expID = nil
  @@domain = nil

  #
  # Return the ID of this Experiment
  #
  # [Return] the experiment's ID (String)
  #
  def Experiment.ID
    if (@@expID == nil)
      ts = DateTime.now.strftime("%F-%T").split(%r{[:-]}).join('_')
      @@expID = "#{OConfig.domain}_#{ts}"
      TraceState.experiment(:id, @@expID)
    end
    return @@expID
  end

  #
  # Set the ID for this Experiment
  #
  def Experiment.ID=(id)
    @@expID = "#{id}"
  end

  #
  # Load an Experiment definition
  #
  # - uri =  URI of the experiment to load
  #
  def Experiment.load(uri)
    MObject.info("Experiment", "load ", uri)
    TraceState.experiment(:load, uri)
    obj, type = OConfig.load(uri, true)
    if type == "text/xml"
      raise "Loading XML file '#{uri}' not implemented."
      # whatever.from_xml(obj.to_xml???)
    elsif type == "text/ruby"
      # already loaded by OConfig.load
    else
      raise IOError, "Unknown experiment source '#{uri}'."
    end
  end

  #
  # Set the array of command line arguments to
  # overide the default experiment variables 
  #
  def Experiment.expArgs=(args)
    MObject.debug "Experiment", "command line args: #{args}."
    while (a = args.shift) != nil
      if (a =~ /^--/) != 0
        warn("Skipping invalid option '", a ,"'.")
      else
        if (value = args.shift) == nil
          warn("Command line property '#{a}' doesn't have a value")
          exit(-1)
        else
          # turn arrays and numbers into native types
          if (value =~ /^(\[|[0-9])/)
            #          if value[0] == ?[
            begin
              pv = eval(value)
              value = pv
            rescue Exception
              # ignore
            end
          end
          @@expPropsOverride[a[2..-1]] = value
        end
      end
    end
  end

  #
  # Set the name of this Experiment
  #
  def Experiment.name=(name)
    @@name = name
    TraceState.experiment(:name, name)
  end

  #
  # Return the name of this Experiment
  #
  def Experiment.name ()
    @@name
  end

  #
  # Set the project for this Experiment
  #
  def Experiment.project=(name)
    @@projectName = name
    TraceState.experiment(:project, name)
  end

  #
  # Set the domain for this Experiment
  #
  def Experiment.domain=(domain)
    MObject.debug('Experiment', "Domain: #{domain}")
    @@domain = domain
    TraceState.experiment(:domain, domain)
  end

  #
  # Return the domain of this Experiment
  #
  def Experiment.domain()
    @@domain
  end

  #
  # Return the domain of this Experiment
  #
  def Experiment.getDomain()
    if @@domain != nil 
       return @@domain
    else
       return OConfig.domain
    end
  end

  #
  # Set the message for this Experiment
  #
  def Experiment.message=(message)
    @@message = message
    TraceState.experiment(:message, message)

  end

  #
  # Set the comma separated string containing tags for this Experiment
  #
  def Experiment.tags=(tags)
    @@tags = tags.split(',')
    TraceState.experiment(:tags, tags)
  end

  #
  # Set the start mode for this Experiment
  #
  def Experiment.startMode=(mode)
    @@startMode = mode
    TraceState.experiment(:startMode, mode)
  end

  # 
  # Set the Root Document for this Experiment
  #
  def Experiment.documentRoot=(path)
    OMF::ExperimentController::Web::documentRoot(path)
  end

  # 
  # Set/Create the property (ExperimentProperty) for this Experiment
  #
  def Experiment.defProperty(name, defaultValue, description)
    if (override = @@expPropsOverride[name]) != nil
      MObject.debug('Experiment', 'Setting property "', name, '" to "', override.inspect, '".')
      defaultValue = override
    end
    ExperimentProperty.create(name, defaultValue, description)
  end

  #
  # Return a binding to an experiment-wide property
  #
  def Experiment.property(paramName, altName = nil)
    return PropertyContext[paramName]
  end

  #
  # Return the context for setting experiment wide properties
  #
  def Experiment.props
    return PropertyContext
  end

  #
  # Observe experiment for x milliseconds
  #
  # - time = time in milliseconds to sleep
  #
  def Experiment.sleep(time)
    TraceState.experiment(:status, "SLEEPING")
    ::Kernel.sleep time
    TraceState.experiment(:status, "RUNNING")
  end

  #
  # Start the Experiment
  #
  def Experiment.start()
    allGroups.powerOn
    if NodeHandler.JUST_PRINT
      Thread.new() {
        while (true)
          Kernel.sleep(5)
          Node.each { |n|
            if (n.poweredAt != -1)
              n.heartbeat(0, 0, 0)
            end
          }
        end
      }
    end
  end

  #
  # Stop an Experiment and do some clean up
  #
  def Experiment.done
    MObject.info "Experiment", "DONE!"
    TraceState.experiment(:status, "DONE")
    NodeHandler.exit
  end
end


class PropertyContext < MObject

  def PropertyContext.[](paramName)
    return ExperimentProperty.create(paramName)
  end

  def PropertyContext.method_missing(name, args = nil)
    name = name.to_s
    if setter = (name[-1] == ?=)
      name.chop!
    end
    name = name.to_sym
    p = ExperimentProperty[name]
    if (p == nil)
      raise "Unknown experiment property '#{name}', " + \
            "should be '#{ExperimentProperty.names.join(', ')}'"
    end
    if setter
      p.set(args)
    else
      return p
    end
  end
end


class ExperimentProperty < MObject

  # Contains all the experiment properties
  @@properties = Hash.new
  
  # Holds all observers on property creation and modifications
  @@observers = []

  def self.[] (name)
    return @@properties[name.to_s]
  end
  
  # Iterate over all experiment properties. The block
  # will be called with the respective property as single
  # argument
  #
  def self.each(sortNames = true, &block)
    names = @@properties.keys
    if (sortNames)
      names = names.sort
    end
    names.each {|n|
      block.call(@@properties[n])
    }
  end

  def self.create(name, value = nil, description = nil)
    name = name.to_s
    p = nil
    if (p = @@properties[name]) != nil
      p.value = value if value != nil
      p.description = description if description != nil
    else
      p = ExperimentProperty.new(name, value, description)
      @@properties[name] = p
      @@observers.each { |proc|
        proc.call(:create, p)
      }
    end
    return p
  end

  def self.names()
    return @@properties.keys
  end

  def self.propertyRootEl= (el)
    @@expProps = el
  end

  def self.propertyRootEl()
    @@expProps
  end
  
  def self.add_observer(&proc)
    @@observers << proc
  end


  attr_reader :name, :value, :description, :id

  private :initialize
  def initialize(name, value = nil, description = nil)
    super("prop.#{name}")

    @name = name.to_s
    @description = description
    @bindings = Array.new
    @changeListeners = Array.new

    @id = "ep_#{name}"
#    el = @@expProps.add_element('property',
#    {'name' => @name, 'id' => @id})

    state = {'id' => @id, 'description' => description}
    TraceState.property(name.to_s, :new, state)


#    @valEl = el.add_element('value')
#    if description != nil
#      el.add_element('description').text = description
#    end
    set(value)
  end

  #  def bindTo(nodeSet, name)
  #    @bindings += [{:ns => nodeSet, :name => name}]
  #  end

  def onChange (&block)
    debug("Somebody bound to me")
    @changeListeners << block
  end


  def set(value)
    @value = value
    #    @bindings.each {|b|
    #      b[:ns].send(:set, [b[:name], value])
    #    }
    info(@name, ' = ', value.inspect, ':', value.class)
    @changeListeners.each { |l|
      l.call(value)
    }
    TraceState.property(@name, :set, {'value' => value.inspect})
  end

  def to_s()
    @value
  end

end
