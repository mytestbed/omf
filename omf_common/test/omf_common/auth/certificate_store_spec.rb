# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'

describe OmfCommon::Auth::CertificateStore do
  before do
    OmfCommon::Auth::CertificateStore.init
    @private_folder = "#{File.dirname(__FILE__)}/../../fixture"
  end

  after do
    OmfCommon::Auth::CertificateStore.reset
  end

  it "must register certificate instance" do
    cert = OmfCommon::Auth::Certificate.create_from_pem(File.read "#{@private_folder}/1st_level.pem")

    OmfCommon::Auth::CertificateStore.instance.register_trusted(cert)
    OmfCommon::Auth::CertificateStore.instance.cert_for("/C=AU/ST=NSW/L=Sydney/O=NICTA/CN=ROOT CA/emailAddress= ").must_equal cert
  end

  it "must verify certificate aginst store" do
    # 2 level CAs
    cert_1 = OmfCommon::Auth::Certificate.create_from_pem(File.read "#{@private_folder}/1st_level.pem")
    cert_2 = OmfCommon::Auth::Certificate.create_from_pem(File.read "#{@private_folder}/2nd_level.pem")
    cert_3 = OmfCommon::Auth::Certificate.create_from_pem(File.read "#{@private_folder}/3rd_level.pem")

    OmfCommon::Auth::CertificateStore.instance.verify(cert_2.to_x509).must_equal false

    OmfCommon::Auth::CertificateStore.instance.register_trusted(cert_1)

    OmfCommon::Auth::CertificateStore.instance.verify(cert_2.to_x509).must_equal true
    OmfCommon::Auth::CertificateStore.instance.verify(cert_3.to_x509).must_equal false

    OmfCommon::Auth::CertificateStore.instance.register_trusted(cert_2)

    OmfCommon::Auth::CertificateStore.instance.verify(cert_3.to_x509).must_equal true

    # 1 level CA
    cert_4 = OmfCommon::Auth::Certificate.create_root
    key = OpenSSL::PKey::RSA.new(2048)
    cert_5 = cert_4.create_for_resource('my_add', :my_resource)

    OmfCommon::Auth::CertificateStore.instance.verify(cert_4.to_x509).must_equal true
    OmfCommon::Auth::CertificateStore.instance.verify(cert_5.to_x509).must_equal true
  end

  it "wont die if registering same cert again" do
    cert_1 = OmfCommon::Auth::Certificate.create_from_pem(File.read "#{@private_folder}/1st_level.pem")
    OmfCommon::Auth::CertificateStore.instance.register_trusted(cert_1)
    OmfCommon::Auth::CertificateStore.instance.register_trusted(cert_1)
  end
end
