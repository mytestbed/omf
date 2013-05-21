# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'

describe OmfCommon::Auth::SSHPubKeyConvert do
  it "must import ssh pub key format to ruby rsa instance" do
    private_folder = "#{File.dirname(__FILE__)}/../../fixture"

    pub_key = OpenSSL::PKey::RSA.new(File.read("#{private_folder}/omf_test.pub.pem"))

    ssh_pub_key = File.read("#{private_folder}/omf_test.pub")

    OmfCommon::Auth::SSHPubKeyConvert.convert(ssh_pub_key).to_s.must_equal pub_key.to_s
  end
end
