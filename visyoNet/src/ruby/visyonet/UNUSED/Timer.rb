#this is the timer class which we can call to calulate the timing patterns
class Timer
 #private member variables
 @starttime = nil
 @endtime = nil
 
 #initialize this class
 def initialize()
    @starttime = nil
    @endtime = nil
 end
 

 #start timer
 def start()
   @starttime = Time.new
   return 
 end
 
 #stop timer
 def stop()
    @endtime = Time.new
    return
 end
 
 #calculate elapsed time
 
 def elapsedtime()
   if ((@starttime != nil) && (@endtime != nil))
      arraysttime = ("%.6f" % @starttime).split(".")
      arrayendtime = ("%.6f" % @endtime).split(".")
      elapsec = (arrayendtime[0].to_f - arraysttime[0].to_f)
      elapusec = (arrayendtime[1].to_f - arraysttime[1].to_f)
      abselapusec = elapusec.abs
      elapsec = elapsec + abselapusec/(1000000)
      checkelap = abselapusec
      puts "Elapsed Time in Seconds = "+ elapsec.to_s
   else
    puts "Wrong usage of class : Timer.start; Timer.stop; Timer.calelapsedtime"   
   end
  return
 end
end
