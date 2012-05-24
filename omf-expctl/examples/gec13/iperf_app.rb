defApplication('iperf_app', 'iperf') do |a|

  a.version(2, 0, 5)
  #a.path = "/usr/bin/oml2-iperf"
  a.path = "/usr/bin/iperf"
  a.shortDescription = 'Iperf traffic generator and bandwidth measurement tool'
  a.description = %{
Iperf is a traffic generator and bandwidth measurement tool. It provides
generators producing various forms of packet streams and port for sending these
packets via various transports, such as TCP and UDP.
  }

  a.defProperty('interval', 
                'pause n seconds between periodic bandwidth reports',
                '-i', {:type => :integer, :dynamic => false})
  a.defProperty('len', 'set length read/write buffer to n (default 8 KB)',
		            '-l', {:type => :string, :dynamic => false})
  a.defProperty('print_mss', 
                'print TCP maximum segment size (MTU - TCP/IP header)',
		            '-m', {:type => :boolean, :dynamic => false})
  a.defProperty('output', 
                'output the report or error message to this specified file',
                '-o', {:type => :string, :dynamic => false})
  a.defProperty('port', 
                'set server port to listen on/connect to to n (default 5001)',
                '-p', {:type => :integer, :dynamic => false})
  a.defProperty('udp', 'use UDP rather than TCP',
                '-u', {:order => 2, :type => :boolean, :dynamic => false})
  a.defProperty('window', 'TCP window size (socket buffer size)',
                '-w', {:type => :integer, :dynamic => false})
  a.defProperty('bind', 'bind to <host>, an interface or multicast address',
                '-B', {:type => :string, :dynamic => false})
  a.defProperty('compatibility',
                'for use with older versions does not sent extra msgs',
                '-C', {:type => :boolean, :dynamic => false})
  a.defProperty('mss', 'set TCP maximum segment size (MTU - 40 bytes)',
                '-M', {:type => :integer, :dynamic => false})
  a.defProperty('nodelay', 'set TCP no delay, disabling Nagle\'s Algorithm',
                '-N', {:type => :boolean, :dynamic => false})
  a.defProperty('IPv6Version', 'set the domain to IPv6',
                '-V', {:type => :boolean, :dynamic => false})
  a.defProperty('reportexclude',
                '[CDMSV] exclude C(connection) D(data) M(multicast) S(settings) V(server) reports',
                '-x', {:type => :string, :dynamic => false})
  a.defProperty('reportstyle', 'C or c for CSV report, O or o for OML',
                '-y', {:type => :string, :dynamic => false})

  a.defProperty('server', 'run in server mode',
                '-s', {:type => :boolean, :dynamic => false})

  a.defProperty('bandwidth', 
                'set target bandwidth to n bits/sec (default 1 Mbit/sec)',
                '-b', {:type => :string, :dynamic => false})
  a.defProperty('client', 'run in client mode, connecting to <host>',
                '-c', {:order => 1, :type => :string, :dynamic => false})
  a.defProperty('dualtest', 'do a bidirectional test simultaneously',
                '-d', {:type => :boolean, :dynamic => false})
  a.defProperty('num', 'number of bytes to transmit (instead of -t)', 
                '-n', {:type => :integer, :dynamic => false})
  a.defProperty('tradeoff', 'do a bidirectional test individually',
                '-r', {:type => :boolean, :dynamic => false})
  a.defProperty('time', 'time in seconds to transmit for (default 10 secs)',
                '-t', {:type => :integer, :dynamic => false})
  a.defProperty('fileinput', 'input the data to be transmitted from a file',
                '-F', {:type => :string, :dynamic => false})
  a.defProperty('stdin', 'input the data to be transmitted from stdin',
                '-I', {:type => :boolean, :dynamic => false})
  a.defProperty('listenport', 'port to recieve bidirectional tests back on',
                '-L', {:type => :integer, :dynamic => false})
  a.defProperty('parallel', 'number of parallel client threads to run',
                '-P', {:type => :integer, :dynamic => false})
  a.defProperty('ttl', 'time-to-live, for multicast (default 1)',
                '-T', {:type => :integer, :dynamic => false})
  a.defProperty('linux-congestion', 
                'set TCP congestion control algorithm (Linux only)',
                '-Z', {:type => :boolean, :dynamic => false})

  a.defMeasurement("application"){ |m|
    m.defMetric('pid', :long, 'Main process identifier')
    m.defMetric('version', :string, 'Iperf version')
    m.defMetric('cmdline', :string, 'Iperf invocation command line')
    m.defMetric('starttime_s', :long, 'Time the application was received (s)')
    m.defMetric('starttime_us', :long, 'Time the application was received (us)')
  }

  a.defMeasurement("settings"){ |m|
    m.defMetric('pid', :long, 'Main process identifier')
    m.defMetric('server_mode', :long, '1 if in server mode, 0 otherwise')
    m.defMetric('bind_address', :string, 'Address to bind')
    m.defMetric('multicast', :long, '1 if listening to a Multicast group')
    m.defMetric('multicast_ttl', :long, 'Multicast TTL if relevant')
    m.defMetric('transport_protocol', :long, 'Transport protocol (IANA number)')
    m.defMetric('window_size', :long, 'TCP window size')
    m.defMetric('buffer_size', :long, 'UDP buffer size')
  }

  a.defMeasurement("connection"){ |m|
    m.defMetric('pid', :long, 'Main process identifier')
    m.defMetric('connection_id', :long, 'Connection identifier (socket)')
    m.defMetric('local_address', :string, 'Local network address')
    m.defMetric('local_port', :long, 'Local port')
    m.defMetric('foreign_address', :string, 'Remote network address')
    m.defMetric('foreign_port', :long, 'Remote port')
  }

  a.defMeasurement("transfer"){ |m|
    m.defMetric('pid', :long, 'Main process identifier')
    m.defMetric('connection_id', :long, 'Connection identifier (socket)')
    m.defMetric('begin_interval', :long, 
                'Start of the averaging interval (Iperf timestamp)')
    m.defMetric('end_interval', :long, 
                'End of the averaging interval (Iperf timestamp)')
    m.defMetric('size', :long, 'Amount of transmitted data [Bytes]')
  }

  a.defMeasurement("losses"){ |m|
    m.defMetric('pid', :long, 'Main process identifier')
    m.defMetric('connection_id', :long, 'Connection identifier (socket)')
    m.defMetric('begin_interval', :long, 
                'Start of the averaging interval (Iperf timestamp)')
    m.defMetric('end_interval', :long, 
                'End of the averaging interval (Iperf timestamp)')
    m.defMetric('total_datagrams', :long, 'Total number of datagrams')
    m.defMetric('lost_datagrams', :long, 'Number of lost datagrams')
  }

  a.defMeasurement("jitter"){ |m|
    m.defMetric('pid', :long, 'Main process identifier')
    m.defMetric('connection_id', :long, 'Connection identifier (socket)')
    m.defMetric('begin_interval', :long, 
                'Start of the averaging interval (Iperf timestamp)')
    m.defMetric('end_interval', :long, 
                'End of the averaging interval (Iperf timestamp)')
    m.defMetric('jitter', :long, 'Average jitter [ms]')
  }

  a.defMeasurement("packets"){ |m|
    m.defMetric('pid', :long, 'Main process identifier')
    m.defMetric('connection_id', :long, 'Connection identifier (socket)')
    m.defMetric('packet_id', :long, 
                'Packet sequence number for datagram-oriented protocols')
    m.defMetric('packet_size', :long, 'Packet size')
    m.defMetric('packet_time_s', :long, 'Time the packet was processed (s)')
    m.defMetric('packet_time_us', :long, 'Time the packet was processed (us)')
    m.defMetric('packet_sent_time_s', :long, 
                'Time the packet was sent (s) for datagram-oriented protocols')
    m.defMetric('packet_sent_time_us', :long, 
                'Time the packet was sent (us) for datagram-oriented protocols')
  }

end

# Local Variables:
# mode:ruby
# vim: ft=ruby:sw=2
# End:
