require 'blather/client/dsl'
require 'oml4r'

module OmfCommon
  module DSL
    module Xmpp
      class Foo < OML4R::MPBase
        name :sin
        param :label
        param :angle, :type => :int32
        param :value, :type => :double
      end
    end
  end
end
