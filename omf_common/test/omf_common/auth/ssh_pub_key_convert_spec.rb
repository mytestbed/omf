require 'test_helper'

describe OmfCommon::Auth::SSHPubKeyConvert do
  it "must import ssh pub key format to ruby rsa instance" do
    private_folder = "#{File.dirname(__FILE__)}/../../fixture"

    pub_key = OpenSSL::PKey::RSA.new(File.read("#{private_folder}/omf_test.pub.pem"))

    ssh_pub_key = File.read("#{private_folder}/omf_test.pub")

    OmfCommon::Auth::SSHPubKeyConvert.convert(ssh_pub_key).to_s.must_equal pub_key.to_s
  end
end
