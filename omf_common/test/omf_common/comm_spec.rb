require 'test_helper'

describe OmfCommon::Comm do
  describe 'when initialised with a pubsub implementation' do
    it 'must return a instance with all methods defined in corresponding module loaded' do
      @comm = OmfCommon::Comm.new(:xmpp)
      %w(connect disconnect create_node delete_node subscribe unsubscribe publish).each do |m|
        @comm.must_respond_to m
      end

      # also existing blather DSL should work  too
      %w(when_ready shutdown).each do |m|
        @comm.must_respond_to m
      end
    end
  end
end
