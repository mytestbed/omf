PROJECTS = %w(omf_common omf_rc omf_ec)
errors = []

desc "Run test task for all projects by default"
task :default => :test

desc "Run test task for all projects"
task :test do
  PROJECTS.each do |project|
    system("cd #{project} && bundle && bundle update") || errors << project
    system("cd #{project} && #{$0} install") || errors << project
    system("cd #{project} && #{$0} test") || errors << project
  end
  fail("Errors in #{errors.join(', ')}") unless errors.empty?
end

desc "Release gems for all projects (Run rake test first)"
task :release do
  version = `git describe --tags`.chomp
  PROJECTS.each do |project|
    system("cd #{project} && gem push pkg/#{project}-#{version}.gem") || errors << project
  end
  fail("Errors in #{errors.join(', ')}") unless errors.empty?
end
