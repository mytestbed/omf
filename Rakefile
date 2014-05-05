PROJECTS = %w(omf_common omf_rc omf_ec)
BUNDLE_LOCATION = "../vendor/bundle"
errors = []

desc "Run test task for all projects by default"
task :default => :test_all

desc "Run test task for all projects"
task :test_all do
  PROJECTS.each do |project|
    system("cd #{project} && bundle install --path #{BUNDLE_LOCATION} && bundle update") || errors << project
    system("cd #{project} && rake install") || errors << project
    system("cd #{project} && rake test") || errors << project
  end
  fail("Errors in #{errors.join(', ')}") unless errors.empty?
end

desc "Build and install gems for all projects"
task :install_all do
  PROJECTS.each do |project|
    system("cd #{project} && bundle install --path #{BUNDLE_LOCATION} && bundle update") || errors << project
    system("cd #{project} && rake install") || errors << project
  end
  fail("Errors in #{errors.join(', ')}") unless errors.empty?
end

desc "Release gems for all projects"
task :release_all do
  version = `git describe --tags`.chomp
  puts "We will use the latest git repository tag as the version number of the gems"
  puts "Please make sure your tag name is following the convention of gem version number (e.g. 1.0.1)\n"
  print "We found that your tag is: #{version}. Proceed? (y/n) "

  if STDIN.gets.chomp =~ /^y|Y$/
    PROJECTS.each do |project|
      system("cd #{project} && rake build && gem push pkg/#{project}-#{version}.gem") || errors << project
    end
    fail("Errors in #{errors.join(', ')}") unless errors.empty?
  end
end
