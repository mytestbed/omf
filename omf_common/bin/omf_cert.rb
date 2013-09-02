#!/usr/bin/env ruby
BIN_DIR = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
TOP_DIR = File.join(BIN_DIR, '..')
$: << File.join(TOP_DIR, 'lib')

require 'json/jwt' # to get around dependencies with activesupport

DESCR = %{
Program to create, read, and manipulate X509 certificates used in OMF
}

DEF_SUBJECT_PREFIX = '/C=US/ST=CA/O=ACME/OU=Roadrunner'

require 'omf_common'
OPTS = {
  duration: 3600 * 365 * 10,
}

op = OptionParser.new
op.banner = "\nUsage: #{op.program_name} [options] cmd \n#{DESCR}\n"
op.on '-o', '--out FILE', "Write result into FILE [STDOUT]" do |file|
  OPTS[:out] = file
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
op.on '--duration SEC', "Duration the cert will be valid for [#{OPTS[:duration]}]" do |secs|
  OPTS[:duration] = secs
end

op.on_tail('-h', "--help", "Show this message") { $stderr.puts op; exit }
rest = op.parse(ARGV) || []

if rest.length != 1
  $stderr.puts "ERROR: Can't figure out what is being requested\n"
  $stderr.puts op; exit
end

OmfCommon::Auth::CertificateStore.init()

def write(content)
  if (fname = OPTS[:out]) && fname != '-'
    File.open(fname, 'w') {|f| f.puts content}
  else
    puts content
  end
end

case cmd = rest[0]
when /^cre/
  cert = OmfCommon::Auth::Certificate.create_root(OPTS)
  write cert.to_pem
  exit
else
  $stderr.puts "ERROR: Unknown cmd '#{cmd}'\n"
  $stderr.puts op; exit
end

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
