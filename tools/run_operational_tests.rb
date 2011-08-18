#!/usr/bin/ruby

require "fileutils"

# Some constant
OMLURI = "tcp:norbit.npc.nicta.com.au:3003"
ECPATH = "/usr/bin/omf-5.4"
ECOPTS = "-O -l system:exp:stdlib,system:exp:eventlib,system:exp:testlib"
TESTPATH = "test:exp"
LOGPATH = "/tmp"
RESETDELAY = 30
RESETTRIES = 0
EXPFILE = 'exp.rb'

# List of resources to use for the test batch
RESPOOL = {:r1 => 'omf.nicta.node36', 
           :r2 => 'omf.nicta.node37'}

# List of tests to perform
TESTLIST = ['test01', 'test02', 'test03', 'test04', 'test05', 'test06']

# Some inits
batchID = Time.now.to_i
respath = "test-#{batchID}"
FileUtils.mkdir(respath)
puts "\nTest Batch ID: #{batchID}"
puts "Started at: #{Time.now}"
puts " "

# Run each tests...
TESTLIST.each do |t|

  STDOUT.sync = true
  expID = "#{t}-#{batchID}"
  print "- Running test: '#{t}' (#{expID})... "
  # Call the EC with the experiment test
  outpath = "#{respath}/#{expID}.result"
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
    puts "Result: UNKNOWN (Error: #{ex})"
  end
  # Store the experiment STDOUT and EC log file in case the user 
  # wants to know more about what happened
  f = File.open("#{respath}/#{expID}.stdout", 'w')
  f.puts(cmd+"\n")
  f.puts(result)
  f.close
  FileUtils.cp("#{LOGPATH}/#{expID}.log", respath)
  FileUtils.cp("#{LOGPATH}/#{expID}-state.xml", respath) 
  # wait 
  sleep(2)
end

puts "\nFinished at: #{Time.now} - Duration: #{Time.now.to_i - batchID} sec\n"
