# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'

describe OmfCommon::Auth::Certificate do
  before do
    OmfCommon::Auth::CertificateStore.init

    @root = OmfCommon::Auth::Certificate.create_root

    OmfCommon::Auth::CertificateStore.instance.register(@root)
  end

  after do
    OmfCommon::Auth::CertificateStore.reset
  end

  it "must create a self-signed root CA cert" do
    @root.must_be_kind_of OmfCommon::Auth::Certificate

    @root.addresses.must_be_kind_of Hash
    @root.addresses.must_equal({ email: "sa@acme.org", geni: "acme.org+authority+sa" })

    @root.subject.must_be_kind_of OpenSSL::X509::Name
    @root.subject.to_s(OpenSSL::X509::Name::RFC2253).must_equal "CN=sa,OU=Roadrunner,O=ACME,ST=CA,C=US"
    @root.key.must_be_kind_of OpenSSL::PKey::RSA
    @root.digest.must_be_kind_of OpenSSL::Digest::SHA1

    cert = @root.to_x509
    cert.must_be_kind_of OpenSSL::X509::Certificate

    # It is self signed
    cert.issuer.must_equal @root.subject
    cert.verify(cert.public_key).must_equal true
  end

  it "must create an end-entity cert using root cert" do
    lambda { @root.create_for_resource }.must_raise ArgumentError

    @entity = @root.create_for_resource('my_addr', 'my_resource')
    cert = @entity.to_x509

    cert.issuer.must_equal @root.subject
    cert.issuer.wont_equal cert.subject

    cert.issuer.to_s(OpenSSL::X509::Name::RFC2253).must_equal "CN=sa,OU=Roadrunner,O=ACME,ST=CA,C=US"
    cert.subject.to_s(OpenSSL::X509::Name::RFC2253).must_match /CN=my_addr\/type=my_resource\/uuid=.+,OU=Roadrunner,O=ACME,ST=CA,C=US/

    cert.verify(@root.to_x509.public_key).must_equal true

    @entity.verify_cert.must_equal true
  end

  it "must be verified successfully by using X509 cert store" do
    store = OpenSSL::X509::Store.new
    store.add_cert(@root.to_x509)

    @entity = @root.create_for_resource('my_addr', 'my_resource')

    store.verify(@root.to_x509).must_equal true
    store.verify(@entity.to_x509).must_equal true
  end

  it "must verify cert validity" do
    @root.verify_cert.must_equal true
    @root.create_for_resource('my_addr', :my_resource).verify_cert.must_equal true
  end

  describe "when init from an exisitng cert in pem format" do
    before do
      @private_folder = "#{File.dirname(__FILE__)}/../../fixture"
      @cert = OmfCommon::Auth::Certificate.create_from_pem(File.read("#{@private_folder}/omf_test.cert.pem"))
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

  describe "when provided an existing cert with a private key attached" do
    it "must parse it into a Certificate instance correctly" do
      private_folder = "#{File.dirname(__FILE__)}/../../fixture"

      x509_cert = File.read("#{private_folder}/omf_test.cert.pem")
      priv_key = File.read("#{private_folder}/omf_test.pem")
      pub_key = File.read("#{private_folder}/omf_test.pub.pem")

      # Now create an instance using this cert
      test_entity = OmfCommon::Auth::Certificate.create_from_pem(x509_cert + priv_key)
      test_entity.to_x509.public_key.to_s.must_equal  pub_key.to_s
      test_entity.can_sign?.must_equal true
      test_entity.to_x509.check_private_key(OpenSSL::PKey::RSA.new(priv_key)).must_equal true
    end
  end
end
