# This resourse is related with an ovsdb-server (interface of an OVSDB database) and behaves as a proxy between experimenter and this.
#
module OmfRc::ResourceProxy::VirtualOpenflowSwitchFactory
  include OmfRc::ResourceProxyDSL

  # The default arguments of the communication between this resource and the ovsdb-server
  OVS_CONNECTION_DEFAULTS = {
    ovsdb_server_host:   "localhost",
    ovsdb_server_port:   "6635",
    ovsdb_server_socket: "/usr/local/var/run/openvswitch/db.sock",
    ovsdb_server_conn:   "unix", # default "unix", between "tcp" and "unix"
    ovs_vswitchd_pid:    "/usr/local/var/run/openvswitch/ovs-vswitchd.pid",
    ovs_vswitchd_socket: "/usr/local/var/run/openvswitch/ovs-vswitchd.%s.ctl",
    ovs_vswitchd_conn:   "unix" #default "unix", between "tcp" and "unix"
  }


  register_proxy :virtual_openflow_switch_factory

  utility :virtual_openflow_switch_tools


  # Checks if the created child is an :virtual_openflow_switch resource and passes the connection arguments
  hook :before_create do |resource, type, opts|
    if type.to_sym != :virtual_openflow_switch
      raise "This resource doesn't create resources of type "+type
    end
    #opts = Hashie::Mash.new(opts)
    arguments = {
      "method" => "transact",
      "params" => [ "Open_vSwitch",
                    { "op" => "insert",
                      "table" => "Interface",
                      "row" => {"name" => opts.name.to_s, "type" => "internal"},
                      "uuid-name" => "new_interface"
                    },
                    { "op" => "insert",
                      "table" => "Port",
                      "row" => {"name" => opts.name.to_s, "interfaces" => ["named-uuid", "new_interface"]},
                      "uuid-name" => "new_port"
                    },
                    { "op" => "insert",
                      "table" => "Bridge",
                      "row" => {"name" => opts.name.to_s, "ports" => ["named-uuid", "new_port"], "datapath_type" => "netdev"},
                      "uuid-name" => "new_bridge"
                    },
                    { "op" => "mutate",
                      "table" => "Open_vSwitch",
                      "where" => [],
                      "mutations" => [["bridges", "insert", ["set", [["named-uuid", "new_bridge"]]]]]
                    }
                  ],
      "id" => "add-switch"
    }
    result = resource.ovs_connection("ovsdb-server", arguments)["result"]
    raise "The requested switch already existed in ovsdb-server or other problem" if result[4]
    opts.property ||= Hashie::Mash.new
    opts.property.provider = ">> #{resource.uid}"
    opts.property.ovs_connection_args = resource.property.ovs_connection_args
    opts.property.uuid = result[2]["uuid"][1]
  end

  # A new resource uses the default connection arguments (ip adress, port, socket, etc) to connect with a ovsdb-server instance
  hook :before_ready do |resource|
    resource.property.ovs_connection_args = OVS_CONNECTION_DEFAULTS
  end


  # Configures the ovsdb-server connection arguments (ip adress, port, socket, etc)
  configure :ovs_connection do |resource, ovs_connection_args|
    raise "Connection with a new ovsdb-server instance is not allowed if there exist created switches" if !resource.children.empty?
    resource.property.ovs_connection_args.update(ovs_connection_args)
  end


  # Returns the ovsdb-server connection arguments (ip adress, port, socket, etc)
  request :ovs_connection do |resource|
    resource.property.ovs_connection_args
  end

  # Returns a list of virtual openflow switches, that correspond to the ovsdb-server bridges.
  request :switches do |resource|
    arguments = {
      "method" => "transact", 
      "params" => [ "Open_vSwitch", 
                    { "op" => "select", 
                      "table" => "Bridge", 
                      "where" => [], 
                      "columns" => ["name"]
                    }
                  ],
      "id" => "switches"
    }
    result = resource.ovs_connection("ovsdb-server", arguments)["result"]
    result[0]["rows"].map {|hash_name| hash_name["name"]}
  end
end
