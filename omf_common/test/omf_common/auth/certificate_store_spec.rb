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
    cert = OmfCommon::Auth::Certificate.create_from_x509(File.read "#{@private_folder}/1st_level.pem")

    OmfCommon::Auth::CertificateStore.instance.register(cert, 'ca1')

    OmfCommon::Auth::CertificateStore.instance.cert_for("ca1").must_equal cert
  end

  it "must verify certificate aginst store" do
    # 2 level CAs
    cert_1 = OmfCommon::Auth::Certificate.create_from_x509(File.read "#{@private_folder}/1st_level.pem")
    cert_2 = OmfCommon::Auth::Certificate.create_from_x509(File.read "#{@private_folder}/2nd_level.pem")
    cert_3 = OmfCommon::Auth::Certificate.create_from_x509(File.read "#{@private_folder}/3rd_level.pem")


    # 1 level CA

    cert_4 = OmfCommon::Auth::Certificate.create(nil, 'omf_ca', 'ca', 'omf')
    key = OpenSSL::PKey::RSA.new(2048)
    cert_5 = cert_4.create_for('my_add', 'bob', 'my_resource', 'omf', 365, key.public_key)

    OmfCommon::Auth::CertificateStore.instance.verify(cert_2.to_x509).must_equal false

    OmfCommon::Auth::CertificateStore.instance.register(cert_1)
    OmfCommon::Auth::CertificateStore.instance.verify(cert_2.to_x509).must_equal true
    OmfCommon::Auth::CertificateStore.instance.verify(cert_3.to_x509).must_equal false

    OmfCommon::Auth::CertificateStore.instance.register(cert_2)
    OmfCommon::Auth::CertificateStore.instance.verify(cert_3.to_x509).must_equal true
    OmfCommon::Auth::CertificateStore.instance.verify(cert_5.to_x509).must_equal false

    OmfCommon::Auth::CertificateStore.instance.register(cert_4)
    OmfCommon::Auth::CertificateStore.instance.verify(cert_5.to_x509).must_equal true
  end

  it "wont die if registering same cert again" do
    cert_1 = OmfCommon::Auth::Certificate.create_from_x509(File.read "#{@private_folder}/1st_level.pem")
    OmfCommon::Auth::CertificateStore.instance.register(cert_1)
    OmfCommon::Auth::CertificateStore.instance.register(cert_1)
  end
end
