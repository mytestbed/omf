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
# = traceState.rb
#
# == Description
#
# This file defiles the TraceState, NodeElement, NodeBuiltin, ImageNodeApp, 
# and NodeApp classes
#

require 'omf-expctl/nodeHandler'

#
# This class will log any changes in the internal state of the experiment 
#
class TraceState < MObject
  
  # Use Singleton design pattern
  include Singleton

  #
  # Initialize the unique instant of TraceState
  #
  def self.init()
    self.instance
    self.experiment(:status, "CONFIGURING")
  end

  #
  # Add or log the value of a (new) property of the Tracecestate
  # instance
  #
  # - name = name of the property to add or set the value
  # - command = either ':new' to create a new property or ':set' to set the value of an existing one
  # - option = a Hash with options. If command is ':new', options are ':id', ':description'. 
  #            If command is ':set' option is 'value'
  #
  # TODO: use ':value' instead of 'value' for the option key... need to modify rest of codes...
  #
  def self.property(name, command, options = {})
    if (command == :new)
      attr = {'name' => name, 'id' => options[:id]}
      el = @@expProps.add_element('property', attr)
      if ((desc = options[:description]) != nil)
        el.add_element('description').text = desc
      end
      @@valEl[name] = el
    elsif (command == :set)
      value = options['value']
      el = @@valEl[name]
      instance.setValue(el, value)
    end
  end

  #
  # Log the value(s) of a tag of the TraceState instance status of the experiment. Create the tag if 
  # it does not exist yet.
  #
  # - arg = see description of 'command'
  # - command = if ':tags' then add new tags contained in 'arg'
  #             else add a new tag with the name of 'command' and the values in 'arg'
  #
  def self.experiment(command, arg)

    case command
    when :tags
      if (el = @@expRoot.elements['tags']) == nil
        el = @@expRoot.add_element('tags')
      end
      arg.split(',').each {|tag|
        el.add_element('tag').text = tag.strip
      }
    else
      name = command.to_s
      if (el = @@expRoot.elements[name]) == nil
        el = @@expRoot.add_element(name)
      end
      el.text = arg
    end
  end

  #
  # Add a new node to the TraceState instance
  #
  # - node = the node Object to add
  # - name = the ID of the node to add
  #
  def self.nodeAdd(node, name)
    self.instance.nodeAdd(node, name)
  end

  #
  # Add a new node to a group in the TraceState instance
  #
  # - node = the node Object to add
  # - group = the group to add the node to
  #
  def self.nodeAddGroup(node, group)
    self.instance.nodeAddGroup(node, group)
  end

  #
  # Return the state of a Node
  #
  # - node =  the node, which state should be returned
  #
  # [Return] an XML tree with the node's state 
  #
  def self.getNodeState(node)
    self.instance.getNodeComponent(node, :root)
  end

  #
  # Log the state of a Node
  #
  # - node =  the node, which state should be set
  # - status = the new state for this node
  #
  def self.nodeStatus(node, status)
    el = self.instance.getNodeComponent(node, :status)
    instance.setValue(el, status)
  end

  #
  # Log the value of a property of a Node
  #
  # - node =  the node, which state should be set
  # - name =  the name of the property to set
  # - value = the new value for this property
  #
  def self.nodeProperty(node, name, value)
    key = 'prop:#{name}'
    el = self.instance.getNodeComponent(node, key, true)
    instance.setValue(el, value)
  end

  #
  # Log the value and status of a configuration attribut of a Node
  #
  # - node =  the node, which state should be set
  # - name =  the name of the config attribut
  # - value = the new value for this attribut
  # - status = the new status for this attribut
  #
  def self.nodeConfigure(node, name, value, status)
    key = "cfg:#{name}"
    el = self.instance.getNodeComponent(node, key, name)
    el.attributes['status'] = status
    instance.setValue(el, value, {'status' => status})
  end

  #
  # Log an Heartbeat message received by a Node
  #
  # - node =  the node, which received the heartbeat
  # - sendSeqNo = sender's sequence number from the heartbeat
  # - recvSeqNo = receiver's sequence number from the heartbeat
  # - timestamp = timestamp from the heartbeat
  #
  def self.nodeHeartbeat(node, sendSeqNo, recvSeqNo, timestamp)
    hb = self.instance.getNodeComponent(node, :heartbeat)
    hb.add_attribute('ts', "#{timestamp}")
    hb.add_attribute('sentPackets', "#{sendSeqNo}")
    hb.add_attribute('receivedPackets', "#{recvSeqNo}")
  end

  #
  # Log the image loaded onto a Node
  #
  # - node =  the node, which image should be logged 
  # - imageName = the name of the image loaded on this node
  # 
  def self.nodeImage(node, imageName)
    self.instance.getNodeComponent(node, :image).text = imageName
  end

  #
  # Log a new Application to a Node 
  # 
  # - node = the node running this application
  # - appCtxt = the Application Context (AppContext) to log
  #
  def self.nodeAddApplication(node, appCtxt)
    procEl = self.instance.getNodeComponent(node, 'apps', 'apps')
    appEl = NodeApp.new(appCtxt, self, procEl)
    self.instance.setNodeComponent(node, "#{appCtxt.id}", appEl)
  end

  #
  # Log the process of a disk image saving for a given Node
  #
  # - node = the node having its disk image saved
  # - imgName = the name for the disk image
  # - nsfDir = the NSF path to the saved disk image
  # - disk = the disk device being saved
  #
  def self.nodeSaveImage(node, imgName, nsfDir, disk)
    procEl = self.instance.getNodeComponent(node, 'apps', 'apps')
    params = {:imgName => imgName, :nsfDir => nsfDir, :disk => disk}
    appEl = NodeBuiltin.new('save_image', params, self, procEl, 'ISSUED')
    self.instance.setNodeComponent(node, 'builtin:save_image', appEl)
  end

  #
  # Log the process of a disk image loading for a given Node
  #
  # - node = the node where the disk image is loaded to 
  # - image = the name for the loaded disk image
  # - opts = options for this disk image loading
  #
  def self.nodeLoadImage(node, image, opts)
    procEl = self.instance.getNodeComponent(node, 'apps', 'apps')
    appEl = ImageNodeApp.new(opts, self, procEl)
    appEl.setStatus('ISSUED')
    self.instance.setNodeComponent(node, 'builtin:load_image', appEl)
  end

  #
  # Log an Event coming from an Application running on a Node
  #
  # - node = the node running the application
  # - eventName = the name of the event produced by the application
  # - appName = the name of the application producing the event
  # - op = application options
  # - message = the message contained in the event
  #
  def self.nodeOnAppEvent(node, eventName, appName, op, message)
    app = self.instance.getNodeComponent(node, appName)
    app.onEvent(node, op, eventName, message)
  end

  @@valEl = {}
  @@nodeEl = {}
  @@nodeRoot = nil
  @@nodeColsEl = Array.new
  @@groupsEl = Hash.new

  def initialize()
    @@expRoot = NodeHandler::EXPERIMENT_EL
    @@expProps = @@expRoot.add_element('properties')
  end


  def nodeAdd(node, name)
    # maintain XML shadow of node state
#    rowEl = @@nodeColsEl[x]
#    if rowEl == nil
#      if @@nodeRoot == nil
#        @@nodeRoot = NodeHandler::NODES_EL
#      end
#      rowEl = @@nodeRoot.add_element('row', {'x' => x})
#      @@nodeColsEl[x] = rowEl
#    end
    n = @@nodeEl[node] = {}
    #n[:root] = el = NodeElement.new(node, nodeId, rowEl, nil, nodeId)

    nodesEl = NodeHandler::NODES_EL
    n[:root] = el = NodeElement.new(node, name, nodesEl, nil, name)
    n[:status] = el.add_element("status", {'value' => Node::STATUS_DOWN})

    n[:image] = imgEl = el.add_element("image")
    imgEl.text = "Unknown"

    n[:heartbeat] = el.add_element("heartbeat")
#    n[:poweredAt] = el.add_element("powered")
#    n[:checkedInAt] = el.add_element("checkedIn")

    n[:properties] = el.add_element("properties")
  end

  def nodeAddGroup(node, group)
    n = @@nodeEl[node]
    groupsEl = n[:groups] ||= n[:root].add_element('groups')
    groupsEl.add_element('group').text = group

#    groupEl = @@groupsEl[group]
#    if groupEl == nil
#      groupEl = @@nodeRoot.add_element('group', {'name' => group})
#      @@groupsEl[group] = groupEl
#    end
#    nodeId = node.nodeId
#    NodeElement.new(node, nodeId, groupEl, @@nodeEl[node][:root], nodeId)
  end

  def getNodeComponent(node, name, createName = nil)
    n = @@nodeEl[node]
    if (n == nil)
      warn("Tracing unknown node '#{node}'")
      return nil
    end
    comp = n[name]
    if (comp == nil)
      if (createName != nil)
        if createName.kind_of?(Array)
          comp = createPath(n[:root], createName)
        else
          comp = n[:root].add_element(createName)
        end
        n[name] = comp
      else
        debug("Tracing unknown node component '#{name}' for node '#{node}' (#{n.keys.join(':')})")
        return nil
      end
    end
    comp
  end

  #
  # Return an XML element whose 'path' (an array) is relative
  # to 'parent'
  #
  def createPath(parent, path)
    el = nil
    path.each {|name|
      if (el = parent.elements[name]) == nil
        el = parent.add_element(name)
      end
      parent = el
    }
    return el
  end

  def setNodeComponent(node, name, comp)
    n = @@nodeEl[node]
    if (n == nil)
      warn("Tracing unknown node '#{node}'")
      return nil
    end
    n[name] = comp
  end

  def setValue(el, value, historyAttr = {})
    if value.kind_of? ExperimentProperty
      el.attributes['value'] = historyAttr['value'] = value.value
      el.attributes['value_ref'] = value.id
    else
      el.attributes['value'] = historyAttr['value'] = value
    end

    historyAttr['ts'] = NodeHandler.getTS()
    el.add_element('history', historyAttr)
  end
  
  def setValueAttr(el, value)
    
  end
end

#
# XML element representing a Node
#
class NodeElement < REXML::Element

  attr_reader :node

  def initialize(node, name, parent, refEl, id)
    super('node', parent, nil)
    @node = node
    @refEl = refEl

    if refEl == nil
      # direct element
      add_attribute('id', "#{id}")
      add_attribute('name', "#{name}");
    else
      @elements = refEl.elements
      #p @elements
      @attributes = refEl.attributes
      @children = refEl._children
      @href = id
    end
  end

  def _children
  puts ">> #{@children.join(':')}"
    return @children
  end
end


#
# Helper class for built in commands
#
class NodeBuiltin < MObject

  # @param vName Virtual name given to this app
  # @param paramBindings Parameter bindings for this application
  # @param node Node this application belongs to
  # @param procEl 'apps' element in state tree
  #
  def initialize(vName, paramBindings, node, procEl, status = 'UNKNOWN')
    @name = vName
    @node = node
    @el = procEl.add_element('builtin', {'name' => vName.to_s})
    @statusEl = @el.add_element('status')
    setStatus(status)

    @param = @el.add_element('properties')
    if (paramBindings != nil)
      paramBindings.each {|k, v|
        if v.class == ExperimentProperty
          @param.add_element(k.to_s, {'idref' => v.id}).text = v.value
        else
          @param.add_element(k.to_s).text = v.to_s
        end
      }
    end
    @io = @ioOut = @ioErr = nil

  end

  def addProperty(name, value)
    @param.add_element(name.to_s).text = value
  end

  def setStatus(status)
    TraceState.instance.setValue(@statusEl, status)
#    @statusEl.text = status
#    @statusEl.add_element('history', {'ts' => NodeHandler.getTS()}).text = status
  end

  def getIoEl()
    if @io == nil
      @io = @el.add_element('io')
    end
    return @io
  end

  def getStdoutEl()
    if @ioOut == nil
      @ioOut = getIoEl.add_element('out')
    end
    return @ioOut
  end

  def getStderrEl()
    if @ioErr == nil
      @ioErr = getIoEl.add_element('err')
    end
    return @ioErr
  end

  def addLine(ioEl, message)
    ioEl.add_element('line', {'ts' => NodeHandler.getTS()}).text = message
  end

  def onEvent(node, op, eventName, message)
    case eventName
    when 'STARTED'
      setStatus "STARTED"
    when 'DONE.OK'
      setStatus "DONE.OK"
      msg = "Application '#{@name}' on '#{node}' finished successfully "
      message.delete!("\"")
      case message
      when "status: 0"
        msg = msg + "(end of application)"
      when "status: 9"
        msg = msg + "(closed by Resource Controller)"
      else
        msg = msg + "(returned: '#{message}')"
      end
      debug(msg)
    when 'DONE.ERROR'
      setStatus "DONE.ERROR"
      debug("Application '#{@name}' on '#{node}' finished with error "+
            "(error message: '#{message}')")
    when 'STDOUT'
      addLine(getStdoutEl, message)
    when 'STDERR'
      addLine(getStderrEl, message)
      lines = Array.new
      lines << "The resource '#{node}' reports that an error occured "
      lines << "while running the application '#{@name}'"
      lines << "The error message is '#{message}'" if message
      NodeHandler.instance.display_error_msg(lines)
    else
      setStatus "UNKNOWN.EVENT: #{eventName} #{message}"
    end
  end
end

#
# Helper class for loading image
#
class ImageNodeApp < NodeBuiltin

  # @param paramBindings Parameter bindings for this application
  # @param node Node this application belongs to
  # @param procEl 'apps' element in state tree
  #
  def initialize(paramBindings, node, procEl, status = 'UNKNOWN')
    super('load_image', paramBindings, node, procEl, status = 'UNKNOWN')
    @progress =  @param.add_element("progress")
    setProgress(0)
  end

  def setStatus(status)
    super(status)
    if status == "DONE.OK"
      setProgress(100)
    end
  end

  def addLine(ioEl, message)
    super(ioEl, message)
    # Check for message nil class
    # Otherwise error occurs if match on a nil class is attempted
    if (message.nil?)
      match = nil
    else
      match = message.match(/^Progress: ([0-9]*)/)
    end
    if match != nil
      setProgress(match[1])
    end
  end

  def setProgress(progress)
    @progress.text = progress.to_s
    @progress.attributes['ts'] = NodeHandler.getTS()
  end
end


#
# Helper class for applications running on a node
#
class NodeApp < NodeBuiltin

  # @param app Application definition
  # @param vName Virtual name given to this app
  # @param paramBindings Parameter bindings for this application
  # @param env Envioronment to set before starting application
  # @param node Node this application belongs to
  # @param procEl 'apps' element in state tree
  #
  #  appEl = NodeApp.new(appCtxt.app.appDefinition, appCtxt.id, appCtxt.bindings, appCtxt.env, self, procEl)
  def initialize(appCtxt, node, procEl)
    super(appCtxt.id, appCtxt.bindings, node, procEl,
            appCtxt.app.installable? ? "INSTALL_PENDING" : "INSTALLED.OK")
    @env = appCtxt.env

    @el.name = 'app'
    @isReady = ! appCtxt.app.installable?
    @el.add_element('appDef', {'href' => appCtxt.app.appDefinition.uri})

    env = appCtxt.getENVConfig
    if env != nil
      envEl = @el.add_element('envList')
      env.each {|k, v|
        envEl.add_element('env', {'name' => k.to_s}).text = v.to_s
      }
    end

    omlconf = appCtxt.getOMLConfig
    if omlconf != nil
      omlEl = @el.add_element('omlConfig')
      omlEl.add_element(omlconf)
    end
  end

  def onEvent(node, op, eventName, message)
    if (op == 'install')
      case eventName
        when 'DONE.OK'
          setStatus("INSTALLED.OK")
          @isReady = true
        when 'DONE.ERROR'
          setStatus("INSTALLED.ERROR")
        else
          super(node, op, eventName, message)
      end
    else
      super(node, op, eventName, message)
    end
  end
end
