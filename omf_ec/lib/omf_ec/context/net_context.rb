# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfEc::Context
  class NetContext
    # Wifi frequency channel matching
    FREQUENCY= {
      1 => 2412, 2 => 2417, 3 => 2422, 4 => 2427, 5 => 2432, 6 => 2437,
      7 => 2442, 8 => 2447, 9 => 2452, 10 => 2457, 11 => 2462, 12 => 2467,
      13 => 2472, 14 => 2484, 36 => 5180, 40 => 5200, 44 => 5220, 48 => 5240,
      52 => 5260, 56 => 5280, 60 => 5300, 64 => 5320, 100 => 5500, 104 => 5520,
      108 => 5540, 112 => 5560, 116 => 5580, 120 => 5600, 124 => 5620, 128 => 5640,
      132 => 5660, 136 => 5680, 140 => 5700, 149 => 5745, 153 => 5765, 157 => 5785,
      161 => 5805, 165 => 5825
    }

    attr_accessor :conf

    def initialize(opts)
      self.conf = opts
      self
    end

    def method_missing(name, *args, &block)
      if name =~ /(.+)=/
        net_prop = $1.to_sym
        net_prop = case net_prop
                   when :type then :hw_mode
                   when :ip then :ip_addr
                   else
                     net_prop
                   end
        self.conf.merge!(net_prop => args[0].to_s)
      else
        super
      end
    end

    def map_channel_freq
      if self.conf[:channel] && self.conf[:frequency].nil?
        self.conf[:frequency] = FREQUENCY[self.conf[:channel].to_s.to_i]
      end
      if self.conf[:channel].nil? && self.conf[:frequency]
        self.conf[:channel] = FREQUENCY.keys.find { |k| FREQUENCY[k] == self.conf[:frequency].to_sto_i }
      end
      self
    end
  end
end
