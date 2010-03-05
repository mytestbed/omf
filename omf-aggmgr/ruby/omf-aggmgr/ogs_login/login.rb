# $Id: $

require 'omf-aggmgr/ogs/legacyGridService'
require 'openwfe/util/scheduler'
require 'omf-aggmgr/ogs_login/logind'

include OpenWFE

class LoginService < LegacyGridService
  
  name 'login' # used to register/mount the service, the service's url will be based on it
  info 'Service to facilitate scheduling'
  @@config = nil
  
  s_info "Get status of login service"
  service 'status' do |req, res|
    res['ContentType'] = "text/xml"
    res.body = Login.lstatus()
  end
  
  # Configure the service through a hash of options
  #
  def self.configure(config)
    @@config = config
    #error("Missing configuration 'cfgDir'") if @@config['cfgDir'] == nil
    #error("Missing configuration 'defImage'") if @@config['defImage'] == nil
    #error("Missing configuration 'linkLifetime'") if @@config['linkLifetime'] == nil
    @daemon = LoginDaemon.new(config)
    @daemon.run_every_minute()

	# Scheduler cron setup.
    #scheduler = Scheduler.new
    #scheduler.start
	
	# Minute Cron.  
    #scheduler.schedule("1-60 * * * *") do
    #  t = Time.now
    #  MObject::debug("Minute run at #{t}")
    #  @daemon.run_every_minute
    #end
	
	# 5 minute Cron.
    #scheduler.schedule("5,10,15,20,25,30,35,40,45,50,55,60 * * * *") do
    #  t = Time.now
    #  MObject::debug("Daily run at #{t}")
    #  @daemon.run_daily
    #end
  end
  
end 
