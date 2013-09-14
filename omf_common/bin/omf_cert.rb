#!/usr/bin/env ruby
BIN_DIR = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
TOP_DIR = File.join(BIN_DIR, '..')
$: << File.join(TOP_DIR, 'lib')

require 'json/jwt' # to get around dependencies with activesupport

DESCR = %{
Program to create, read, and manipulate X509 certificates used in OMF.
    create_root ...... Create a root certificate
    create_user ...... Create user certificate (requires: --email, --user)
    create_resource .. Create a certificate for a resource (requires: --resource_type)
    describe ......... Print out some of the key properties found in the cert
}


require 'omf_common'
include OmfCommon::Auth

DEF_SUBJECT_PREFIX = Certificate.default_domain('US', 'CA', 'ACME', 'Roadrunner')

OPTS = {
  duration: Certificate::DEF_DURATION
}

op = OP = OptionParser.new
op.banner = "\nUsage: #{op.program_name} [options] cmd \n#{DESCR}\n"
op.on '-o', '--out FILE', "Write result into FILE [STDOUT]" do |file|
  OPTS[:out] = file
end
op.on '-i', '--in FILE', "Read certificate from FILE [STDIN]" do |file|
  OPTS[:in] = file
end
op.on '--email EMAIL', "Email to add to cert" do |email|
  OPTS[:email] = email
end
op.on '--cn CN', "Common name to use. Will be appended to '#{DEF_SUBJECT_PREFIX}'" do |cn|
  OPTS[:cn] = cn
end
op.on '--subj SUBJECT', "Subject to use in cert [#{DEF_SUBJECT_PREFIX}/CN=dummy]" do |subject|
  OPTS[:subject] = subject
end
op.on '--user USER_NAME', "User name for user certs" do |user|
  OPTS[:user] = user
end
op.on '--resource-type TYPE', "Type of resource to create cert for" do |type|
  OPTS[:resource_type] = type
end
op.on '--resource-id ID', "ID for resource" do |id|
  OPTS[:resource_id] = id
end
op.on '--duration SEC', "Duration the cert will be valid for [#{OPTS[:duration]}]" do |secs|
  OPTS[:duration] = secs
end
op.on '--domain C:ST:O:OU', "Domain to us (components are ':' separated) [#{DEF_SUBJECT_PREFIX}]" do |domain|
  unless (p = domain.split(':')).length == 4
    $stderr.puts "ERROR: Domain needs to contain 4 parts separated by ':'\n"
    exit(-1)
  end
  c, st, o, ou = p
  Certificate.default_domain(c, st, o, ou)
end

op.on_tail('-v', "--verbose", "Print summary of created cert (Surpressed when writing cert to stdout)") do
  OPTS[:verbose] = true
end
op.on_tail('-h', "--help", "Show this message") { $stderr.puts op; exit }
rest = op.parse(ARGV) || []
OPTS[:verbose] = false unless OPTS[:out]

if rest.length != 1
  $stderr.puts "ERROR: Can't figure out what is being requested\n"
  $stderr.puts op; exit
end

CertificateStore.init()

def write(content)
  if (fname = OPTS[:out]) && fname != '-'
    File.open(fname, 'w') {|f| f.puts content}
  else
    puts content
  end
end

def write_cert(cert)
  write cert.to_pem_with_key
  describe_cert(cert) if OPTS[:verbose]
end

def require_opts(*names)
  fails = false
  names.each do |n|
    unless OPTS[n]
      $stderr.puts "ERROR: Missing option '--#{n}'\n"
      fails = true
    end
  end
  exit if fails
end

def describe_cert(cert = nil)
  unless cert
    if cert_file = OPTS[:in]
      if File.readable?(cert_file)
        pem = File.read(cert_file)
      else
        $stderr.puts "ERROR: Can't open file '#{cert_file}' for reading\n"
        exit
      end
    else
      pem = $stdin.read
    end
    cert = Certificate.create_from_pem(pem)
  end
  cert.describe.each do |k, v|
    puts "#{k}:#{' ' * (15 - k.length)} #{v.inspect}"
  end
end

case cmd = rest[0]
when /^cre.*_root/
  require_opts(:email)
  cert = Certificate.create_root(OPTS)
  write_cert cert

when /^cre.*_user/
  root = Certificate.create_root()
  require_opts(:user, :email)
  cert = root.create_for_user(OPTS[:user], OPTS)
  write_cert cert

when /^cre.*_resource/
  root = Certificate.create_root()
  require_opts(:resource_type)
  r_id = OPTS.delete(:resource_id)
  r_type = OPTS.delete(:resource_type)
  cert = root.create_for_resource(r_id, r_type, OPTS)
  write_cert cert

when /^des.*/ # describe
  describe_cert
else
  $stderr.puts "ERROR: Unknown cmd '#{cmd}'\n"
  $stderr.puts op; exit
end

exit

# unless resource_url || resource_type
  # $stderr.puts 'Missing --resource-url --type or'
  # $stderr.puts op
  # exit(-1)
# end

adam = root.create_for_user('adam')
projectA = root.create_for_resource('projectA', :project)
#puts projectA.to_pem

# require 'json/jwt'
# msg = {cnt: "shit", iss: projectA}
# p = JSON::JWT.new(msg).sign(projectA.key , :RS256).to_s

require 'omf_common/auth/jwt_authenticator'

#puts projectA.addresses_raw


p = OmfCommon::Auth::JWTAuthenticator.sign('shit', projectA)
pn = (p.length / 80 + 1).times.map {|i| p[i * 80, 80]}.join("\n")
puts pn

puts pn.split.join == p

puts OmfCommon::Auth::JWTAuthenticator.parse(pn).inspect
