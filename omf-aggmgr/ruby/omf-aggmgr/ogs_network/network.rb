
class NetworkService < AbstractService

 s_description 'Switch configuration service'


 def self.authorize(req, res)
   puts "Checking authorization"
   WEBrick::HTTPAuth.basic_auth(req, res, 'orbit') {|user, pass|
     # this block returns true if
     # authentication token is valid
     isAuth = user == 'gnome' && pass == 'super'
     puts "user: #{user} pw: #{pass} isAuth: #{isAuth}"
     isAuth
   }
   true
 end
end
