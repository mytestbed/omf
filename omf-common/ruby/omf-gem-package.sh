PATH=$PATH:$HOME/.gem/ruby/1.8/bin
echo "Downloading / Upgrading bundler gem"
gem list bundler | grep bundler -q
if [ $? -eq 0 ]; then
   gem update bundler --user-install
else
   gem install bundler --no-rdoc --no-ri --user-install
fi 
echo "Downloading and packaging gems required for OMF"
if [ -d "vendor" ]; then
   rm -rf vendor
fi
bundle pack
cd vendor/cache && gem fetch bundler
