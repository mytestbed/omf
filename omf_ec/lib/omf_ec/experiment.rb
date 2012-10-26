require 'hashie'
require 'singleton'

module OmfEc
  class Experiment
    include Singleton

    attr_reader :property
    attr_reader :state
    attr_accessor :comm
    attr_accessor :groups

    def initialize
      @property ||= Hashie::Mash.new
      @state ||= Hashie::Mash.new
      @comm ||= OmfCommon::Comm.new(:xmpp)
      @groups ||= []
    end

    # Purely for backward compatibility
    class << self
      def done
        @comm.disconnect
      end
    end
  end
end

class Hashie::Mash
  def add_engine(&block)
    each_pair do |key, value|
      value.__send__(:add_engine, &block)
    end
  end
end
