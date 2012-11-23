require 'openssl'
require 'singleton'

module OmfCommon
  class Key
    include Singleton

    attr_accessor :private_key

    def import(filename)
      self.private_key = OpenSSL::PKey.read(File.read(filename))
    end
  end
end
