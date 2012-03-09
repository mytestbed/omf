require 'rake/testtask'
require "bundler/gem_tasks"

task :default => :test

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = "test/**/*_spec.rb"
  t.verbose = true
end
