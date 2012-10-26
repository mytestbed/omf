require 'eventmachine'

# DSL methods to be used for OEDL scripts
#
module OmfEc
  module DSL
    # Experiment instance
    def exp
      Experiment.instance
    end

    # Experiment's communicator instance
    def comm
      exp.comm
    end

    def after(time, &block)
      comm.add_timer(time, block)
    end

    def every(time, &block)
      comm.add_periodic_timer(time, block)
    end

    def def_group(name, &block)
      comm.subscribe(name, true) do |m|
        unless m.error?
          group = Group.new(name)
          exp.groups << group
          block.call group
        end
      end
    end

    alias_method :defGroup, :def_group

    def group(name, &block)
      group = exp.groups.find {|v| v.name == name}
      block.call(group)
    end

    # Exit the experiment
    def done!
      comm.disconnect
    end

    # Create a topic object, subscribe to it, add it to resource tree
    #
    #def def_garage(name)
    #  Experiment.instance.state.garage ||= {}
    #  Experiment.instance.state.garage[name] ||= {}
    #  Experiment.instance.state.garage[name].topic = Experiment.instance.comm.get_topic(name)
    #  Experiment.instance.state.garage[name].topic.subscribe
    #end

    #def all_garages
    #  Experiment.instance.state.garage
    #end

    def get_garage(id)
      exp.state.garage[id]
    end

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
      Experiment.instance.property[name] = default_value
    end

    alias_method :defProperty, :def_property

    # Return the context for setting experiment wide properties
    #
    # [Return] a Property Context
    #
    def property
      Experiment.instance.property
    end

    alias_method :prop, :property


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

    # Check if all elements in array equal the value provided
    #
    def all_equal(array, value)
      array.empty? ? false : array.all? { |v| v.to_s == value.to_s }
    end

    alias_method :allEqual, :all_equal

    # Check if any elements in array equals the value provided
    #
    def one_equal(array, value)
      array.any? ? false : array.all? { |v| v.to_s == value.to_s }
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
    # - duration = Time to wait in seconds (can be
    #
    def wait(duration)
      warn "Wait will pause the entire event system, so I won't do it. Please use timer instead."
    end

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
