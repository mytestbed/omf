defProperty('logpath', "unconfigured-logpath", "Path to experiment log")
defProperty('outpath', "unconfigured-outpath", "Path to experiment output")

onEvent(:EXPERIMENT_DONE) do |event|
  begin
    f = File.open("#{property.outpath}", 'w')
    check_outcome ? f.puts("OK") : f.puts("FAILED")
    f.close
  rescue Exception => ex
    puts "TEST - Failed to check the outcome of a test (Error: '#{ex}'"
  end
end
