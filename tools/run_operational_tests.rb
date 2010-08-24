#!/usr/bin/ruby

require "fileutils"

# Some constant
OMLURI = "tcp:norbit.npc.nicta.com.au:3003"
ECPATH = "/usr/bin/omf-5.3"
ECOPTS = "-O -l system:exp:stdlib,system:exp:eventlib,system:exp:testlib"
TESTPATH = "test:exp"
LOGPATH = "/tmp"
RESETDELAY = 30
RESETTRIES = 0
EXPFILE = 'exp.rb'

# List of resources to use for the test batch
RESPOOL = {:r1 => 'omf.nicta.node2', :r2 => 'omf.nicta.node3'}

# List of tests to perform
TESTLIST = ['test01', 'test02', 'test03', 'test04', 'test05', 'test06']

# Some inits
batchID = Time.now.to_i
puts "\nTest Batch ID: #{batchID}"
puts "Started at: #{Time.now}"
puts " "

# Run each tests...
TESTLIST.each do |t|

  STDOUT.sync = true
  print "- Running test: '#{t}'... "
  # Call the EC with the experiment test
  expID = "#{t}-#{batchID}"
  outpath = "#{expID}.result"
  cmd = "#{ECPATH} exec #{ECOPTS} -e #{expID} --oml-uri #{OMLURI}"+
        " #{TESTPATH}:#{t} --"+
        " --res1 #{RESPOOL[:r1]} --res2 #{RESPOOL[:r2]}"+
        " --resetDelay #{RESETDELAY} --resetTries #{RESETTRIES}"+
        " --logpath #{LOGPATH} --outpath #{outpath}"
  #puts cmd
  result =`#{cmd}`
  # Output the OK or FAILED result
  begin
    puts "Result: #{File.new(outpath).read}"
  rescue Exception => ex
    puts "Result: FAILED (#{ex})"
  end
  # Store the experiment STDOUT and EC log file in case the user 
  # wants to know more about what happened
  f = File.open("#{expID}.stdout", 'w')
  f.puts(cmd+"\n")
  f.puts(result)
  f.close
  FileUtils.cp("#{LOGPATH}/#{expID}.log", "./")
  FileUtils.cp("#{LOGPATH}/#{expID}-state.xml", "./")  
  # wait 
  sleep(2)
end

puts "\nFinished at: #{Time.now}\n"
