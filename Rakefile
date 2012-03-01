PROJECTS = %w(omf_common omf_rc omf_ec)

desc "Run test task for all projects by default"
task :default => :test

desc "Run test task for all projects"
task :test do
  PROJECTS.each do |project|
    system(%(cd #{project} && bundle))
    system(%(cd #{project} && #{$0} install))
    system(%(cd #{project} && #{$0} test))
  end
end
