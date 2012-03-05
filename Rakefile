PROJECTS = %w(omf_common omf_rc omf_ec omf_tools)

desc "Run test task for all projects by default"
task :default => :test

desc "Run test task for all projects"
task :test do
  errors = []
  PROJECTS.each do |project|
    system("cd #{project} && bundle") || errors << project
    system("cd #{project} && #{$0} install") || errors << project
    system("cd #{project} && #{$0} test") || errors << project
  end
  fail("Errors in #{errors.join(', ')}") unless errors.empty?
end
