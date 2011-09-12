  ### IMPLEMENTATION

  def get_version
    {
      :geni_api => 1,
      :omf_am => "0.1"
    }
  end

  def list_resources(credentials, options)
    check_credentials(:ListResources, credentials)
    only_available = options["geni_available"]
    compressed = options["geni_compressed"]
    slice_urn = options["geni_slice_urn"]

    p = 'urn:publicid:IDN+mytestbed.net+'
    Nokogiri::XML::Builder.new do |xml|
      now = Time.now
      xml.rspec('xmlns' => 'http://www.protogeni.net/resources/rspec/0.1',
                'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                'generated' => now.iso8601,
                'valid_until' => (now + 86400).iso8601,
                'type' => 'advertisement'
                ) do
        xml.resource('component_manager_uuid' => p + 'authority+cm',
                 'component_name' => 'pc1',
                 'component_uuid' => p + 'node+pc1'
                 ) do
          xml.available "true"
          xml.exclusive "true"
          xml.interface('component_id' => p + 'interface+pc1:eth0')
        end
      end
    end.to_xml
  end

  def create_sliver(slice_urn, credentials, rspec, users)
    check_credentials(:CreateSliver, credentials)
    puts "SICE URN: #{slice_urn}"
    puts "RPSEC: #{rspec}"
    puts "USERS: #{users.inspect}"
    rspec
  end

  def sliver_status(slice_urn, credentials)
    check_credentials(:SliverStatus, credentials)
    status = {}
    status['geni_urn'] = slice_urn
    status['geni_status'] = 'ready'
    status['geni_error'] =  ""
    rs = status['geni_resources'] = []
    rs << {
      'geni_urn'=> "SSSS",
      'geni_status' => 'ready',
      'geni_error' => ""
    }

    status
  end

  def renew_sliver(slice_urn,credentials, expiration_time)
    check_credentials(:RenewSliver, credentials)
    true
  end

  def delete_sliver(slice_urn, credentials)
    check_credentials(:DeleteSliver, credentials)
    puts "SLICE URN: #{slice_urn}"
    true
  end

  def shutdown_sliver(slice_urn, credentials)
    check_credentials(:Shutdown, credentials)
    puts "SLICE URN: #{slice_urn}"
    true
  end

  private 

  # Throws exception if _credentials_ are *not* sufficient for _action_
  #
  def check_credentials(action, credentials)
puts @request.env.keys.sort.join("\n")
exit

  end

  # Define public RPC interface
  #
#  rpc 'GetVersion' => :get_version
#  rpc 'ListResources' => :list_resources

end