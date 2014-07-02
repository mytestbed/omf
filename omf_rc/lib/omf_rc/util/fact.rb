require 'facter'

module OmfRc::Util::Fact
  include OmfRc::ResourceProxyDSL

  Facter.each do |k, v|
    request "fact_#{k}" do
      v
    end
  end

  request :facts do
    Facter.to_hash
  end
end
