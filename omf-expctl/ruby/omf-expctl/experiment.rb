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

  # When in disconnection mode, the interval at which to check if
  # the experiment is done (i.e. all resources report that they are done)
  DISCONNECT_INTERVAL = 10 # in sec

  @@name = "UNKNOWN"  # name of experiment
  @@expPropsOverride = Hash.new  # from command line options
  @@expID = nil
  @@disconnectionAllowed = false
  @@sliceID = nil
  @@domain = nil
  @@is_running = false

  attr_reader :domain

  #
  # Return the ID of this Experiment
  #
  # [Return] the experiment's ID (String)
  #
  def Experiment.ID
    if (@@expID == nil)
      # since we use the exp ID as the pubsub user name
      # we need to get rid of ":" and uppercase characters
      ts = DateTime.now.to_s.gsub(':','.').downcase
      @@expID = "#{@@sliceID}-#{ts}"
      #YTraceState.experiment(:id, @@expID)
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
  # Set the slice ID for this Experiment
  #
  def Experiment.sliceID=(id)
    @@sliceID = "#{id}"
  end

  #
  # Return the slice ID of this Experiment
  #
  def Experiment.sliceID
    return @@sliceID 
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
    MObject.debug "Experiment", "command line args: '#{args.join(' ')}'"
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
  # NOTE: deprecated? not used anywhere else in the code, but not sure
  # what needed this in the 1st place. Need to check before removing.
  #
  #def Experiment.startMode=(mode)
  #  @@startMode = mode
  #  TraceState.experiment(:startMode, mode)
  #end

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
  #  Set the Flag indicating that this Experiment Controller (EC) is invoked 
  #  for an Experiment that support temporary disconnections
  #       
  def Experiment.allow_disconnection
    # Check if EC is NOT in 'Slave Mode'
    # When is 'Slave Mode' this mean there is already a Master EC which has 
    # its 'disconnection mode' set so we do nothing here
    @@disconnectionAllowed = true if !NodeHandler.SLAVE
  end

  #
  # Return the Disconnection Mode of this Experiment (i.e. does this 
  # experiment allow disconnected resources or not)
  #
  def Experiment.disconnection_allowed?
    return @@disconnectionAllowed 
  end

  #
  # Observe experiment for x second
  #
  # - time = time in second to sleep
  #
  def Experiment.sleep(time)
    TraceState.experiment(:status, "SLEEPING")
    ::Kernel.sleep time
    TraceState.experiment(:status, "RUNNING")
  end

  def Experiment.state(xpath)
    result = Array.new
    el = TraceState.getExperimentState
    m = REXML::XPath.match(el, xpath)
    m.each { |e| result << e.to_s }
    return nil if result.size == 0
    return result
  end

  #
  # Start the Experiment
  #
  def Experiment.start
    @@is_running = true
    TraceState.experiment(:id, @@expID)

    # If -r flag was set on the command line
    # Reset the nodes before starting the experiment if -r flag was set
    if NodeHandler.NODE_RESET
      MObject.info "Reset flag is set - Resetting the resources"
      OMF::ExperimentController::CmdContext.instance.allGroups.powerReset
    # If not, just make sure the nodes are ON
    else
      OMF::ExperimentController::CmdContext.instance.allGroups.powerOn
    end

    # If this is a disconnected experiment, purge all Events defined on this 
    # EC for this experiment (the slave ECs will be responsible for acting
    # on the experiment defined events). Then add a new event to wait for all
    # resources to declare the end of the experiments
    if @@disconnectionAllowed
      MObject.info("Experiment", "Disconnection allowed") 
      MObject.info("Experiment", "All resources should report the completion "+
                   "of their tasks.")
      # Remove all previously defined events, these will be dealt with at
      # the resources
      Event.purge_all
      # Create a new event to detect when all resources are done 
      OMF::ExperimentController::CmdContext.instance.\
      defEvent(:EXPERIMENT_DONE, DISCONNECT_INTERVAL) do |event|
        MObject.info("Experiment","Waiting for all resources to report back...")
        event.fire if Node.all_reconnected?
      end
      OMF::ExperimentController::CmdContext.instance.\
      onEvent(:EXPERIMENT_DONE) { |node| Experiment.close }
      ECCommunicator.instance.allow_retry
    end
 
    # Now we can Enroll the nodes!
    OMF::ExperimentController::CmdContext.instance.allGroups.enroll

    # If this is a disconnected experiment, inform the resources about it
    if @@disconnectionAllowed
     OMF::ExperimentController::CmdContext.instance.allGroups.set_disconnection
    end
  end

  #
  # Set the status of the experiment to 'done'
  # Thus allowing some clean up to happen, if required
  #
  def Experiment.done
    TraceState.experiment(:status, "DONE")
  end

  # 
  # Close an experiment, i.e. tell the Experiment Controller
  # to exit
  #
  def Experiment.close
    @@is_running = false
    NodeHandler.exit(false)
  end
  
  # Return true if experiment is on, otherwise return false
  def self.running?
    @@is_running    
  end
end

#
# This class defines a Context for Experiment Properties
#
class PropertyContext < MObject

  #
  # Return an existing Experiment Property, or create a new
  # one if id does not exist
  #
  # - paramName = the name of the property to return /create
  #
  # [Return] an Experiment Property
  #
  def PropertyContext.[](paramName)
    return ExperimentProperty.create(paramName)
  end

  #
  # Handles missing method, allows to access an existing Experiment
  # Property with the syntax 'propcontext.propname'
  #
  def PropertyContext.method_missing(name, args = nil)
    name = name.to_s
    if setter = (name[-1] == ?=)
      name.chop!
    end
    name = name.to_sym
    p = ExperimentProperty[name]
    if (p == nil)
      raise "Unknown experiment property '#{name}', " + \
            "\n\tKnown properties are '#{ExperimentProperty.names.join(', ')}'"
    end
    if setter
      p.set(args)
    else
      return p
    end
  end

end

#
# This class defines an Experiment Property, and also holds all the 
# properties of an experiment.
#
class ExperimentProperty < MObject

  # Contains all the experiment properties
  @@properties = Hash.new
  
  # Holds all observers on property creation and modifications
  @@observers = []

  #
  # Returns a given property
  # - name =nameof the property to return
  #
  # [Return] a property
  #
  def self.[] (name)
    return @@properties[name.to_s]
  end
  
  #
  # Iterate over all Experiment Properties. The block
  # will be called with the respective property as single
  # argument
  #
  # - sortNames = if 'true' sort the properties (default: true)
  # - &block = the block of commands to call
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

  # 
  # Return an existing Experiment Property, or create a new one
  #
  # - name = name of the property to create/return
  # - value = value to assign to this property
  # - description = short string description for this property
  #
  # [Return] an Experiment Property
  #
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

  #
  # Return the names of the all defined Experiment Properties
  #
  # [Return] an Array with the names of all defined Experiment Properties
  #
  def self.names()
    return @@properties.keys
  end

  # 
  # Set the ROOT element for all defined properties (used to record Experiment state)
  #
  # - el = the root element 
  #
  def self.propertyRootEl= (el)
    @@expProps = el
  end

  # 
  # Return the ROOT element for all defined properties (used to record Experiment state)
  #
  # [Return] the root element 
  #
  def self.propertyRootEl()
    @@expProps
  end
 
  #
  # Add a 'observer' to this Experiment Property
  #
  # - proc = observer to add
  #
  def self.add_observer(&proc)
    @@observers << proc
  end

  attr_reader :name, :value, :description, :id

  private :initialize

  #
  # Create a new Experiment Property
  #
  # - name = name of the property to create/return
  # - value = value to assign to this property
  # - description = short string description for this property
  #
  def initialize(name, value = nil, description = nil)
    super("property.#{name}")
    @name = name.to_s
    @description = description
    @bindings = Array.new
    @changeListeners = Array.new
    @id = "ep_#{name}"
    state = {'id' => @id, 'description' => description}
    TraceState.property(name.to_s, :new, state)
    set(value)
  end

  # 
  # Add a block of command to the list of actions to do 
  # when this property is being changed
  #
  # - &block =  the block of command to add
  #
  def onChange (&block)
    debug("Somebody bound to me")
    @changeListeners << block
  end

  #
  # Update the value of this Experiment Property
  #
  # - value = new value for this property
  #
  def set(value)
    @value = value
    #info(@name, ' = ', value.inspect, '(type:', value.class,')')
    info('value = ', value.inspect, ' (',value.class,')')
    @changeListeners.each { |l|
      l.call(value)
    }
    TraceState.property(@name, :set, {'value' => value.inspect})
  end

  # Explicit conversion to String
  def to_s()
    @value.to_s
  end

  # Implicit conversion to String (required for + operator)
  def to_str()
    @value.to_s
  end

  # Division operator for Integer and Float properties
  def /(right)
    if @value.kind_of?(Integer) || @value.kind_of?(Float)
      return (@value / right)
    else
      raise OEDLIllegalCommandException.new("/", "Illegal operation, Experiment Property '#{@name}' not a float or integer.")
    end
  end

  # Multiplication operator for Integer and Float properties
  def *(right)
    if @value.kind_of?(Integer) || @value.kind_of?(Float)
      return (@value * right)
    else
      raise OEDLIllegalCommandException.new("*", "Illegal operation, Experiment Property '#{@name}' not a float or integer.")
    end
  end

  # Substraction operator for Integer and Float properties
  def -(right)
    if @value.kind_of?(Integer) || @value.kind_of?(Float)
      return (@value - right)
    else
      raise OEDLIllegalCommandException.new("-", "Illegal operation, Experiment Property '#{@name}' not a float or integer.")
    end
  end

  # Addition operator for Integer, Float, and String properties
  def +(right)
    if @value.kind_of?(Integer) || @value.kind_of?(Float) || @value.kind_of?(String) 
      return (@value + right)
    else
      raise OEDLIllegalCommandException.new("+", "Illegal operation, Experiment Property '#{@name}' not a float, integer, or string.")
    end
  end

  # Explicit Coercion for Integer, Float, and String properties
  # (allow property to be on the right-hand of an operator such as +)
  def coerce(other)
    if @value.kind_of?(Integer) || @value.kind_of?(Float) || @value.kind_of?(String) 
      return other, @value
    else
      raise OEDLIllegalCommandException.new("coercion", "Illegal operation, Experiment Property '#{@name}' not a float, integer, or string.")
    end
  end

end
