# $Id: $
require 'ldap'
require 'mysql'

#
# Login class: Description goes here.
# 

# Add on to HASH ...
class Hash
  def inverse
    i = Hash.new
    self.each_pair{ |k,v|
      if (v.class == Array)
        v.each{ |x|
          if i.has_key?(x)
            i[x] = [k,i[x]].flatten
          else
            i[x] = k
          end
        }
      else
        if i.has_key?(v)
          i[v] = [k,i[v]].flatten
        else
          i[v] = k
        end
      end
    }
    return i
  end
end #Hash

class Slot
  attr_reader :user, :resource, :start, :stop
  
  def initialize(user,resource,start,stop)
    @user = user
    @resource = resource
    @start = start
    @stop = stop
  end
  
  def duration
    @stop-@start
  end
  
  def to_s
    "#{@user} -> #{@resource}: from #{@start} to #{@stop} "
  end
  
end # Slot

# Array of slots
class SlotArray < Array
  def duration( resource )
    inject(0) {|sum,s|  s.resource == resource ? sum += s.duration : sum  }
  end
  
  def slots( resource )
    find_all()
  end
end

class LoginDaemon < MObject
  @config     = nil
  @ldapConfig = Hash.new  # LDAP Config
  @con        = nil       # LDAP Connection
  @dbConfig   = Hash.new  # DB Config
  @my         = nil       # MySQL Connection
  @webConfig   = Hash.new # PHPScheduleIt Config
  # XML status
  @statusXML = String.new
  
  def initialize(config)
    @config = config
    if ((@dbConfig = config['database']) == nil)
      raise "Missing 'database' configuration in Login service"
    end
    if ((@ldapConfig = config['ldap']) == nil)
      raise "Missing 'ldap' configuration in Login service"
    end
	if ((@webConfig = config['web']) == nil)
      raise "Missing 'web' configuration in Login service"
    end

    if (@dbConfig['host'].nil? || @dbConfig['user'].nil? || 
      @dbConfig['password'].nil? || @dbConfig['database'].nil?)
      raise "Missing 'host', or 'user', or 'password' configuration " + \
              "in the 'database' section of Login service"
    end
  end
  
  def run_daily()
    openLdap()
    openMy()
    users = slotSearch(-7,0,0)
    p "Found users history for last 7 days"
    users.each{ |user, arr | 
      d = arr.duration("outdoor")
      p "#{user} -> #{d}" 
    }
    close()
  end
  
  def run_every_minute()
    openLdap()
    openMy()
    users = slotSearch(0,0,1)
	clean()
    close()
  end
  
  private
  #
  #Open and Bind ldap  LDAP (authoritative bind) descriptor is @@con.
  def openLdap
    begin
      debug("Connecting to LDAP.")
      @@con = LDAP::Conn.new(@ldapConfig['host'])
    rescue LDAP::ResultError
      e = @@con.err2string()
      debug("LDAP err: #{e}.")
    end
    begin
      @@con.bind("cn=admin,"+@ldapConfig['base'],@ldapConfig['secret'])
    rescue LDAP::ResultError
      e = @@con.err2string()
      debug("LDAP err: #{e}.")
    end   
    debug("LDAP Bound.")
  end
  
  # SQL descriptor is @@my
  def openMy
    host = @dbConfig['host']
    user = @dbConfig['user']
    pw = @dbConfig['password']
    db = @dbConfig['database']
    begin 
      debug("Binding to sql.")
      # MYSQL connect
      @@my = Mysql.connect(host, user, pw, db)
    rescue MysqlError => e
      debug("SQL error message: #{e.error}.")
    end
    debug("MYSQL Bound.")
  end # def init   
  
  #
  # Close LDAP and MYSQL descriptors
  #
  def close
    @@con.unbind()
    @@my.close
  end
  
  def userMinutes()
  end
  
  #SELECT DATE_ADD(NOW(),INTERVAL 14 DAY);
  #SELECT DATE_SUB(NOW(),INTERVAL 14 DAY);
  #
  # Search sql for users currently in slot.  Return as hash of users with array of slots
  # for that user for the specified time period (0,0 for start and end date is a special case 
  # for current time only)
  def slotSearch(startd = 0, endd = 0, pending = 0)
    begin
      users = Hash.new(nil)
      timeCond = nil
      if (startd == 0 && endd == 0)
        timeCond = "unix_timestamp(now()) >= (reservations.start_date + (reservations.startTime * 60)) " \
             	  "AND   unix_timestamp(now()) <= (reservations.end_date   + (reservations.endTime * 60)) "
      else
        if startd >= 0
          timeCond = "unix_timestamp(DATE_ADD(NOW(),INTERVAL #{startd} DAY)) <="\
					" reservations.start_date + (reservations.startTime * 60)) " 
        else
          timeCond = "unix_timestamp(DATE_SUB(NOW(),INTERVAL #{-startd} DAY)) <="\
					" (reservations.start_date + (reservations.startTime * 60)) "
        end
        endd += 1
        if endd >= 0
          timeCond += " AND unix_timestamp(DATE_ADD(NOW(),INTERVAL #{endd} DAY)) >="\
					" (reservations.end_date   + (reservations.endTime * 60)) "
        else
          timeCond += " AND unix_timestamp(DATE_SUB(NOW(),INTERVAL #{-endd} DAY)) >="\
					" (reservations.end_date + (reservations.endTime * 60)) "
        end
      end

      qs = "SELECT login.logon_name, resources.name, "\
                    "reservations.start_date, reservations.startTime,"\
                    "reservations.end_date, reservations.endTime "\
             		"FROM reservations "\
             		"LEFT JOIN reservation_users ON reservation_users.resid = reservations.resid "\
             		"LEFT JOIN login             ON login.memberid  = reservation_users.memberid "\
             		"LEFT JOIN resources         ON reservations.machid = resources.machid "\
                    "WHERE #{timeCond} AND is_pending = #{pending};"

      begin 
        results=@@my.query(qs)
        if results.each() { |uid,machine,sdate,stime,edate,etime|
            s = Slot.new(uid,machine,Integer(sdate)+Integer(stime)*60,Integer(edate)+Integer(etime)*60)
            if users.has_key?(uid) #if user already exists
              users[uid].push(s)
            else
              users[uid] =SlotArray.[](s) #add new slot
            end
            debug("User #{uid} has approved slot for #{machine}.")
          }
        end
        if users.empty?
          debug("No users have slot with matching condition.")
        end
      rescue MysqlError => e
        debug("SQL error message: #{e.error}.")
      end
      return users
    end #begin
  end #slotSearch
  
# #
# #Search sql for users currently in slot.  Return as hash of users in slot
# #for which host.  user => host
# #
# def slotSearchOld()
#   begin
#     users = Hash.new(nil)
#     qs = "SELECT #{@dbConfig['CAL_LGN']}.logon_name, #{@dbConfig['CAL_RSC']}.name "\
#          "FROM #{@dbConfig['CAL_RSV']} "\
#          "LEFT JOIN #{@dbConfig['CAL_RSVUSRS']} ON #{@dbConfig['CAL_RSVUSRS']}.resid = #{@dbConfig['CAL_RSV']}.resid "\
#          "LEFT JOIN #{@dbConfig['CAL_LGN']}     ON #{@dbConfig['CAL_LGN']}.memberid  = #{@dbConfig['CAL_RSVUSRS']}.memberid "\
#          "LEFT JOIN #{@dbConfig['CAL_RSC']}     ON #{@dbConfig['CAL_RSV']}.machid = #{@dbConfig['CAL_RSC']}.machid "\
#          "WHERE (unix_timestamp(now()) >= (#{@dbConfig['CAL_RSV']}.start_date + (#{@dbConfig['CAL_RSV']}.startTime * 60)) " \
#          "AND unix_timestamp(now()) <= (#{@dbConfig['CAL_RSV']}.end_date + (#{@dbConfig['CAL_RSV']}.endTime * 60)) " \
#          "AND is_pending = 0);"
#     results=@@my.query(qs)
#     if results.each() { |uid,machine|
#         if users.has_key?(uid) #if user already exists
#           users[uid] = [machine,users[uid]].flatten # add [machine1,machine2]
#         else
#           users[uid] = machine #add single [machine]
#         end
#         debug("LOGIN","User #{uid} has approved slot for #{machine}.")
#       }
#     end
#     if users.empty?
#       debug("LOGIN","No users have Approved slots.")
#     end
#     return users
#   end #begin
# end #slotSearch
 
  #
  # Search sql for users in slot - 10 mins.  Return as hash of user
  # for which host.  user => host
  #
  def slotStartWarn()
    begin
      users = Hash.new(nil)
      #{uid => machine}
      reservations = Hash.new(nil)
      qs = "SELECT login.logon_name, resources.name, reservation.resid "\
           "FROM reservations"\
           "LEFT JOIN #{@dbConfig['CAL_RSVUSRS']} ON #{@dbConfig['CAL_RSVUSRS']}.resid = #{@dbConfig['CAL_RSV']}.resid "\
           "LEFT JOIN #{@dbConfig['CAL_LGN']}     ON #{@dbConfig['CAL_LGN']}.memberid  = #{@dbConfig['CAL_RSVUSRS']}.memberid "\
           "LEFT JOIN #{@dbConfig['CAL_RSC']}     ON #{@dbConfig['CAL_RSV']}.machid = #{@dbConfig['CAL_RSC']}.machid "\
           "WHERE ((unix_timestamp(now()) + #{@dbConfig['AUTO_APPROVE']} ) >= ( #{@dbConfig['CAL_RSV']}.start_date + (#{@dbConfig['CAL_
RSV']}.startTime * 60) ) " \
           "AND unix_timestamp(now()) <= ( #{@dbConfig['CAL_RSV']}.end_date + (#{@dbConfig['CAL_RSV']}.endTime * 60) ) " \
           "AND is_pending = 1);"
      debug("LOGIN", "Query made")
      results=@@my.query(qs)
      debug("LOGIN", "Checking for unapproved slots.")
      if results.each() { |uid,machine,resid|
          debug("LOGIN", "SQL DB #{uid} #{machine} #{resid}")
          #hash used to relate uid, machine, and reservation
          #{uid => [machine, resid]}
          reservations[resid] = [uid,machine].flatten
          if users.has_key?(uid) #if user already exists
            users[uid] = [machine,users[uid]].flatten # add [machine1,machine2]
          else
            users[uid]=machine #add single [machine]
          end
          info("LOGIN","User #{uid} has an unapproved slot for #{machine} in the next #{@config['AUTO_APPROVE']} seconds.")
        }
      end
      if users.empty?
        debug("LOGIN","No users have unapproved slots slots in the next #{@config['AUTO_APPROVE']} second interval.")
      end
      return [users, reservations]
    end #begin
  end #slotStartWarn
  
  #
  #modify the host feild of a user
  #
  def addHost(uid,host)
    #      entry1 = [ LDAP.mod(LDAP::LDAP_MOD_REPLACE, 'host', ["#{host}"]) ]
    if (host.class != Array)
      entry1 = [ LDAP.mod(LDAP::LDAP_MOD_REPLACE, 'host', [host]) ]
    else
      entry1 = [ LDAP.mod(LDAP::LDAP_MOD_REPLACE, 'host', host) ]
    end
    debug("LOGIN", entry1)
    begin
      @@con.modify("uid=#{uid},ou=people,#{@ldapConfig["LDAP_BASE"]}", entry1)
      debug("LOGIN","User #{uid} moddified for #{host}.")
    rescue LDAP::ResultError
      @@con.perror("LDAP Modify Error:  ")
    end
    
  end #addHost
  
  #
  #Search LDAP for user and host.  If user is has host field set for specific host,
  #return true.  Otherwise false.
  #
  def ldapSearchHost(uid,host)
    begin
      haveHost = nil
      @@con.search(@ldapConfig["base"], LDAP::LDAP_SCOPE_SUBTREE, "uid=#{uid}",['host']){|e|
        haveHost = e.to_hash['host'].inject(false) {|found, v|
          found || v == host
        }#end haveHost. looks at all elements in array for host.
        return haveHost
      }
    rescue LDAP::ResultError
      @@con.perror("LDAP Search:  ")
    end
  end
  
  
  def webApprove(resid)
    form = @webConfig['form']
    form['resid'] = resid
    url = URI.parse(@webConfig['url'])
    http = Net::HTTP.new(url.host,url.port)
    http.set_debug_output $stderr
    http.use_ssl = true
    req = Net::HTTP::Post.new(url.path)
    req.basic_auth(@webConfig['user'], @webConfig['secret'])
    req.set_form_data(form,'&')
    response = http.start { http.request(req) }
    if response.kind_of?(Net::HTTPOK)
      debug("LOGIN","Auto-approve succeded for #{resid}.")
    else
      debug("LOGIN", "Approve of #{resid} failed with". response.code )
    end
  end
  
  #
  #Grant permissions to users
  #
  def grant()
    #Search for  users in slot
    users = slotSearch() #user = Hash(logon_name => machine).
    added = Hash.new(nil)
    machines = users.inverse() #[consoledomain => uid]
    if users != nil
      users.each { |uid,consoleDomain|
        #Check for *
        haveStar = ldapSearchHost(uid,"*")
        #if machine is not claimed by multiple users
        if (machines[consoleDomain].class != Array)
          haveHost = ldapSearchHost(uid,"console.#{consoleDomain}.orbit-lab.org")
          if (haveStar == false && haveHost == false)
            #Populate host field
            hosts = Array.new
            #single users wants multiple machines.  hash will have array of machines.
            consoleDomain.each { |domain|
              info("LOGIN","Auto adding console.#{domain}.orbit-lab.org to #{uid}.")
              hosts.push("console.#{domain}.orbit-lab.org")
            }
            addHost(uid,hosts)
          end #end if haveStar
        end #end if array
      }#end each user
    end #end if users ! nil
    return added
  end #end Grant
  
  
  #
  # Approve slots that are still pending
  #
  def autoApprove()
    users, reservations = slotStartWarn()
    #user{logon_name => machine}, reservations{[uid,machine]=> resid}
    machines = users.inverse
    machines.each { |consoleDomain, uid|
      #if uid is an array, that is has more than 1 entry,
      #then conflict for that machine.
      if (uid.class != Array)
        info("LOGIN", "Approving #{uid} for #{consoleDomain}.")
        Login.webApprove(reservations.invert[[uid,consoleDomain]])
      else
        info("LOGIN", "#{consoleDomain} has a conflict. Not auto approving.")
      end
    }
  end
  
  #Get list of all users from LDAP
  #Foreach uid, if uid is not in slot AND !ldapsearchhost(uid,null) AND! ldapsearchost(uid,*)
  #CLEAN
  def clean()
    cleaned = Array.new
    windowUsers = slotSearch() #hash of users in slot as reported by calendar db
    #Check to see if users have correct host in ldap.  Get hash of all uids in ldap,
    #if uids not in slot, check to see if host=null.  If not, fix.
    #If user is *, do nothing.
    @@con.search(@ldapConfig["base"], LDAP::LDAP_SCOPE_SUBTREE, "uid=*",['uid']) { |e|
      inWindow = windowUsers.keys.inject(false) {|found, v|
        found || v == e.to_hash['uid'][0]
      } #end inWindow
      #if not in slot, doesnt have nullhose, and doesnt have a star, fix
      if (!inWindow && !ldapSearchHost(e.to_hash['uid'][0],@ldapConfig['nullHost']) && !ldapSearchHost(e.to_hash['uid'][0],'*'))
        info("LOGIN","Cleaning #{@ldapConfig['nullHost']} to #{e.to_hash['uid'][0]}.")
        cleaned.push(e.to_hash['uid'][0])
        addHost(e.to_hash['uid'][0],ORBIT['nullHost'])
      end #end if
    } #end search
    return cleaned
  end #end clean
  
  
  def method_missing(name, *args)
    puts "Missing method #{name}"
  end
  
end
