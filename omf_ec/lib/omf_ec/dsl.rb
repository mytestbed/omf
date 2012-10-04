require 'omf_ec/experiment'

# DSL methods to be used for OEDL scripts
#
module OmfEc
  module DSL
    # Define an experiment property which can be used to bind
    # to application and other properties. Changing an experiment
    # property should also change the bound properties, or trigger
    # commands to change them.
    #
    # - name = name of property
    # - defaultValue = default value for this property
    # - description = short text description of this property
    #
    def def_property(name, default_value, description = nil)
      Experiment.instance.def_property(name, default_value)
    end

    alias_method :defProperty, :def_property

    #
    # Return the context for setting experiment wide properties
    #
    # [Return] a Property Context
    #
    def property
      Experiment.instance.property
    end

    alias_method :prop, :property

    #
    # Define a new topology. The topology can
    # be described by an optionally array declaration, or
    # with a block with the newly created topology as
    # single argument.
    #
    # - refName = the name for this new topology
    # - nodeArray = optional, an array with the node to add in this topology
    # - &block = optional, a block containing commands that define this topology
    #
    # [Return] the newly created Topology object
    #
    def def_topology(refName, nodeArray = nil, &block)
      topo = Topology.create(refName, nodeArray)
      if (! block.nil?)
        block.call(topo)
      end
      return topo
    end

    alias_method :defTopology, :def_topology

    #
    # Define a new prototype. The supplied block is
    # executed with the new Prototype instance
    # as a single argument.
    #
    # - refName = reference name for this property
    # - name = optional, short/easy to remember name for this property
    # - &block = a code-block to execute on the newly created property
    #
    def def_prototype(refName, name = nil, &block)
      p = Prototype.create(refName)
      p.name = name
      block.call(p)
    end

    alias_method :defPrototype, :def_prototype
    #
    # Define a set of nodes to be used in the experiment.
    # This can either be a specific declaration of nodes to
    # use, or a set combining other sets.
    #
    # - groupName = name of this group of nodes
    # - selector = optional, this can be: a String refering to the name of an
    #              existing Topology, or an Array with the name of existing
    #              Groups to add to this group, or an Array explicitly describing
    #              the nodes to include in this group
    # - &block = a code-block with commands, which will be executed on the nodes
    #            in this group
    #
    # [Return] a RootNodeSetPath object referring to this new group of nodes
    #
    def def_group(groupName, selector = nil, &block)
      if (NodeSet[groupName] != nil)
        raise "Node set '#{groupName}' already defined. Choose different name."
      end

      if selector.kind_of?(ExperimentProperty)
        selector = selector.value
      end

      if (selector != nil)
        # What kind of selector do we have?
        if selector.kind_of?(String)
          begin
            # Selector is the name of an existing Topology (e.g. "myTopo")
            topo = Topology[selector]
            ns = BasicNodeSet.new(groupName, topo)
            # This raises an exception if Selector does not refer to an existing
            # Topology
          rescue
            # Selector is a comma-separated list of existing resources
            # These resources are identified by their HRNs
            # e.g. "node1, node2, node3"
            tname = "-:topo:#{groupName}"
            topo = Topology.create(tname, selector.split(","))
            ns = BasicNodeSet.new(groupName, topo)
          end
          # Selector is an Array of String
        elsif selector.kind_of?(Array) && selector[0].kind_of?(String)
          begin
            # Selector is an array of group names
            # Thus we are creating a Group or Groups
            ns = GroupNodeSet.new(groupName, selector)
            # This raises an exception if Selector contains a name, which does
            # not refer to an existing defined Group
          rescue
            # Selector is an array of resource names, which are identified by their
            # HRNs, e.g. ['node1','node2','node3']
            tname = "-:topo:#{groupName}"
            topo = Topology.create(tname, selector)
            ns = BasicNodeSet.new(groupName, topo)
          end
        else
          raise "Unknown node set declaration '#{selector}: #{selector.class}'"
        end
      else
        ns = BasicNodeSet.new(groupName)
      end

      return RootNodeSetPath.new(ns, nil, nil, block)
    end

    alias_method :defGroup, :def_group

    # Evaluate a code-block in the context of a previously defined
    # group of nodes.
    #
    # - groupName = the name of the group of nodes
    # - &block = the code-block to evaluate/execute on the group of nodes
    #
    # [Return] a RootNodeSetPath object referring to the group of nodes
    #
    def group(groupName, &block)
      ns = NodeSet[groupName.to_s]
      if (ns == nil)
        warn "Undefined node set '#{groupName}'"
        return EmptyGroup.new
      end
      return RootNodeSetPath.new(ns, nil, nil, block)
    end

    def resource(resName)
      res = OMF::EC::Node[resName]
      return res
    end

    #
    # Evaluate a code-block over all nodes in all groups of the experiment.
    #
    # - &block = the code-block to evaluate/execute on all the groups of nodes
    #
    # [Return] a RootNodeSetPath object referring to all the groups of nodes
    #
    def all_groups(&block)
      NodeSet.freeze
      ns = DefinedGroupNodeSet.instance
      return RootNodeSetPath.new(ns, nil, nil, block)
    end

    alias_method :allGroups, :all_groups
    #
    # Evalute block over all nodes in an the experiment, even those
    # that do not belong to any groups
    #
    # - &block = the code-block to evaluate/execute on all the nodes
    #
    # [Return] a RootNodeSetPath object referring to all the nodes
    #
    def all_nodes!(&block)
      NodeSet.freeze
      ns = RootGroupNodeSet.instance
      return RootNodeSetPath.new(ns, nil, nil, block)
    end

    alias_method :allNodes!, :all_nodes!

    def all_equal(array, value)
      return false if array.nil? || array.empty?
      res = true
      if array
        array.each { |v| res = false if v.to_s != value.to_s }
      end
      res
    end

    alias_method :allEqual, :all_equal

    def one_equal(array, value)
      res = false
      if array
        array.each { |v| res = true if v.to_s == value.to_s }
      end
      res
    end

    alias_method :oneEqual, :one_equal

    def def_event(name, interval = 5, &block)
      Event.new(name, interval , &block)
    end

    alias_method :defEvent, :def_event

    def on_event(name, consumeEvent = false, &block)
      Event.associate_tasks_to_event(name, consumeEvent, &block)
    end

    alias_method :onEvent, :on_event

    # Periodically execute 'block' every 'interval' seconds until block
    # returns nil.
    #
    # - name = the name for this periodic action
    # - interval = interval at which to execute the action (in sec, default=60)
    # - initial = optional, any initial conditions that will be passed to the
    #             Thread running this code-block
    # - &block = the code-block to periodically execute/evaluate. This periodic
    #            task is stopped when block returns 'nil'
    #
    def every(name, interval = 60, initial = nil, &block)
      Thread.new(initial) { |context|
        while true
          Kernel.sleep(interval)
          MObject.debug("every(#{name}): fires - #{context}")
          begin
            if ((context = block.call(context)) == nil)
              break
            end
          rescue Exception => ex
            bt = ex.backtrace.join("\n\t")
            MObject.error("every(#{name})",
                          "Exception: #{ex} (#{ex.class})\n\t#{bt}")
          end
        end
        MObject.debug("every(#{name}): finishes")
      }
    end

    # Periodically execute 'block' against a group of nodes every 'interval' sec
    #
    # - nodesSelector = the name of the group of nodes
    # - interval = interval at which to execute the action (in sec, default=60)
    # - &block = the code-block to periodically execute/evaluate
    #
    def every_ns(nodesSelector, interval = 60, &block)
      ns = NodeSet[nodesSelector]
      if ns == nil
        raise "Every: Unknown node set '#{nodesSelector}"
      end
      path = RootNodeSetPath.new(ns)
      Thread.new(path) { |path|
        while true
          Kernel.sleep(interval)
          MObject.debug("every", nodesSelector, ": fires")
          begin
            if ! (path.call &block)
              break
            end
          rescue Exception => ex
            bt = ex.backtrace.join("\n\t")
            MObject.error("everyNS", "Exception: #{ex} (#{ex.class})\n\t#{bt}")
          end
        end
        MObject.debug("every", nodesSelector, ": finishes")
      }
    end

    alias_method :everyNS, :every_ns

    # Return the appropriate antenna (set)
    #
    # - x = x coordinate of the antenna
    # - y = y coordinate of the antenna
    # - precision = optional, how close to (x,y) does the antenna really have to
    #               be (default=nil)
    #
    # [Return] an Antenna object
    #
    def antenna(x, y, precision = nil)
      a = Antenna[x, y, precision = nil]
      if (a == nil)
        raise "Undefined antenna within #{x}@#{y}"
      end
      return a
    end

    # Note: we plan to give user full access to SQL query definition in OEDL
    # this will allow them to define JOIN queries to retrieve the name of the
    # oml senders. In the meantime, we provide that information through
    # this method
    def ms_sender_name
      senders = Hash.new
      sql = "SELECT * from _senders"
      url = OConfig.RESULT_SERVICE
      url = url + "/queryDatabase?format=csv&query=#{URI.escape(sql)}"+
      "&expID=#{URI.escape(Experiment.ID,'+')}"
      resp = NodeHandler.service_call(url, "Can't query result service")
      resp.body.each_line do |l|
        name, id = l.split(';')
        senders[id.strip.to_i] = name.strip
      end
      senders
    end

    alias_method :msSenderName, :ms_sender_name

    def t1()
      ms('trace_oml2_radiotap').project(:oml_ts_server, :rate_avg).each do |row|
        puts row.tuple.inspect
      end
    end

    # Wait for some time before issuing more commands
    #
    # - time = Time to wait in seconds (can be
    #
    def wait(time)
      if time.kind_of?(ExperimentProperty)
        duration = time.value
      else
        duration = time
      end
      info "Request from Experiment Script: Wait for #{duration}s...."
      Kernel.sleep duration
    end

    # Debugging support:
    # print an information message to the 'stdout' & the logfile of EC
    #
    # - *msg = message to print
    #
    def info(*msg)
      logger.info *msg
    end

    #
    # Debugging support:
    # print an warning message to the 'stdout' & the logfile of EC
    #
    # - *msg = message to print
    #
    def warn(*msg)
      logger.warn *msg
    end

    #
    # Debugging support:
    # print an error message to the 'stdout' & the logfile of EC
    #
    # - *msg = message to print
    #
    def error(*msg)
      logger.error *msg
    end

    #
    # Reporting/Debugging support:
    # print the XML tree of states/attributs of EC
    #
    def lsx(xpath = nil)
      root = NodeHandler::ROOT_EL
      formatter = REXML::Formatters::Pretty.new()
      if xpath.nil?
        formatter.write(root, $stdout)
      else
        res = REXML::XPath.match(root, xpath)
        res.inject(true) {|isFirst, el|
          puts "\n--------------------------" unless isFirst
          formatter.write(el, $stdout)
          false
        }
      end
      '' # supress additional output from IRB
    end

    #
    # Reporting/Debugging support:
    # print the XML tree of states/attributs of EC
    #
    def ls(xpath = nil)
      root = NodeHandler::ROOT_EL
      if xpath.nil?
        res = NodeHandler::ROOT_EL.children
      else
        res = REXML::XPath.match(root, xpath)
      end

      res.each do |e|
        attrs = e.attributes
        as = ""
        if attrs.size > 0
          res = []
          attrs.each_attribute do |a|
            res << "#{a.name}=#{a.value}"
          end
          as = " (#{res.join(' ')}) "
        end
        puts "#{e.name}#{as} #{e.text}"
      end
      nil # supress additional output from IRB
    end

    def quit()
      NodeHandler.exit(true)
      "Going to exit in a sec"
    end

    def help()
      m = self.methods - Module.methods - DEPRECATED
      m = m - ["warn", "info", "error"]
      m = m.select do |n| !n.start_with? '_' end
      m.sort.join(" ")
    end
  end
end
