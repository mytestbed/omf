require 'nokogiri'

module OMF; module GENI; module AM
  class PrivilegeCredential < Credential

    def initialize(doc)
      @doc = doc
    end

  end # PrivilegeCredential                     
end; end; end # OMF::GENI::AM
