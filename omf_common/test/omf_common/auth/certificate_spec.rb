require 'test_helper'

describe OmfCommon::Auth::Certificate do
  before do
    OmfCommon::Auth::CertificateStore.init

    @root = OmfCommon::Auth::Certificate.create(nil, 'omf_ca', 'ca', 'omf')

    OmfCommon::Auth::CertificateStore.instance.register(@root)
  end

  after do
    OmfCommon::Auth::CertificateStore.reset
  end

  it "must create a self-signed root CA cert" do
    @root.must_be_kind_of OmfCommon::Auth::Certificate
    @root.address.must_be_nil
    @root.subject.must_be_kind_of OpenSSL::X509::Name
    @root.subject.to_s(OpenSSL::X509::Name::RFC2253).must_equal "CN=frcp//omf//frcp.ca.omf_ca"
    @root.key.must_be_kind_of OpenSSL::PKey::RSA
    @root.digest.must_be_kind_of OpenSSL::Digest::SHA1

    cert = @root.to_x509
    cert.must_be_kind_of OpenSSL::X509::Certificate

    # It is self signed
    cert.issuer.must_equal @root.subject
    cert.verify(cert.public_key).must_equal true
  end

  it "must create an end-entity cert using root cert" do
    lambda { @root.create_for }.must_raise ArgumentError

    @entity = @root.create_for('my_addr', 'bob', 'my_resource', 'omf')
    cert = @entity.to_x509

    cert.issuer.must_equal @root.subject
    cert.issuer.wont_equal cert.subject

    cert.issuer.to_s(OpenSSL::X509::Name::RFC2253).must_equal "CN=frcp//omf//frcp.ca.omf_ca"
    cert.subject.to_s(OpenSSL::X509::Name::RFC2253).must_equal "CN=frcp//omf//frcp.my_resource.bob"

    cert.verify(@root.to_x509.public_key).must_equal true

    @entity.verify_cert.must_equal true
  end

  it "must be verified successfully by using X509 cert store" do
    store = OpenSSL::X509::Store.new
    store.add_cert(@root.to_x509)

    @entity = @root.create_for('my_addr', 'bob', 'my_resource', 'omf')

    store.verify(@root.to_x509).must_equal true
    store.verify(@entity.to_x509).must_equal true
  end

  it "must verify cert validity" do
    @root.verify_cert.must_equal true
    @root.create_for('my_addr', 'bob', 'my_resource', 'omf').verify_cert.must_equal true
  end

  describe "when init from an exisitng cert in pem format" do
    before do
      @private_folder = "#{File.dirname(__FILE__)}/../../fixture"
      @cert = OmfCommon::Auth::Certificate.create_from_x509(File.read("#{@private_folder}/omf_test.cert.pem"))
      @key = OpenSSL::PKey::RSA.new(File.read("#{@private_folder}/omf_test.pem"))
      @pub_key = OpenSSL::PKey::RSA.new(File.read("#{@private_folder}/omf_test.pub.pem"))
    end

    it "must verify itself" do
      # It is a self signed cert
      @cert.subject.to_s(OpenSSL::X509::Name::RFC2253).must_equal "O=Internet Widgits Pty Ltd,ST=Some-State,C=AU"
      @cert.to_x509.issuer.to_s(OpenSSL::X509::Name::RFC2253).must_equal "O=Internet Widgits Pty Ltd,ST=Some-State,C=AU"
      @cert.verify_cert.must_equal true
    end

    it "must not have pirivate key initialised"  do
      @cert.can_sign?.must_equal false
    end

    it "must have a correct public key" do
      @pub_key.public?.must_equal true
      @pub_key.private?.must_equal false
      @cert.to_x509.public_key.to_s.must_equal @pub_key.to_s
    end

    it "must have a correct private key associated" do
      @key.public?.must_equal true
      @key.private?.must_equal true
      @cert.to_x509.check_private_key(@key).must_equal true
    end
  end

  describe "when provided an existing public key" do
    it "must generate a cert contains a converted public key" do
      private_folder = "#{File.dirname(__FILE__)}/../../fixture"
      pub_key = OpenSSL::PKey::RSA.new(File.read("#{private_folder}/omf_test.pub.pem"))

      test_entity = @root.create_for('my_addr', 'bob', 'my_resource', 'omf', 365, pub_key)
      test_entity.to_x509.public_key.to_s.must_equal  pub_key.to_s
      test_entity.can_sign?.must_equal false
      test_entity.verify_cert.must_equal true
    end

    it "must generate a cert from SSH key too" do
      private_folder = "#{File.dirname(__FILE__)}/../../fixture"
      ssh_pub_key = File.read("#{private_folder}/omf_test.pub")
      pub_key = OpenSSL::PKey::RSA.new(File.read("#{private_folder}/omf_test.pub.pem"))
      lambda do
        test_entity = @root.create_for('my_addr', 'bob', 'my_resource', 'omf', 365, 'bob')
      end.must_raise ArgumentError

      test_entity = @root.create_for('my_addr', 'bob', 'my_resource', 'omf', 365, ssh_pub_key)
      test_entity.to_x509.public_key.to_s.must_equal  pub_key.to_s
    end
  end

  describe "when provided an existing public cert and I have a private key associated" do
    it "must attach the private key into instance so it could sign messages" do
      private_folder = "#{File.dirname(__FILE__)}/../../fixture"
      key = OpenSSL::PKey::RSA.new(File.read("#{private_folder}/omf_test.pem"))
      pub_key = OpenSSL::PKey::RSA.new(File.read("#{private_folder}/omf_test.pub.pem"))

      x509_cert = @root.create_for('my_addr', 'bob', 'my_resource', 'omf', 365, pub_key).to_x509.to_s

      # Now create an instance using this cert
      test_entity = OmfCommon::Auth::Certificate.create_from_x509(x509_cert, key)
      test_entity.to_x509.public_key.to_s.must_equal  pub_key.to_s
      test_entity.can_sign?.must_equal true
      test_entity.to_x509.check_private_key(key).must_equal true
    end
  end
end
