{
  :available_mps => [
    { :mp => 'radiotap', 
      :fields => [
        {:field => 'sig_strength_dBm', :unit => 'dBm', :type => 'Fixnum'},
        {:field => 'noise_strength_dBm', :unit => 'dBm', :type => 'Fixnum'},
      ]
    },
    { :mp => 'udp', 
      :fields => [
        {:field => 'source', :type => 'String'},
      ]
    },
  ]
}
