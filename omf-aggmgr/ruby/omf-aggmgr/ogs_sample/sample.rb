
class SampleService < AbstractService

 s_description 'Foo is a typical service'
 s_param :x, 'xcoord', 'x coordinates of location'
 s_param :domain, '[sb_name]', 'domain for which to apply this action'
 s_auth :authorize
 service 'foo' do |req, res|
   res.body = "Foo. Always foo."
 end


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
