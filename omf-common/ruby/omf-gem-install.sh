echo "Installing bundler gem"
gem install --no-ri --no-rdoc -l -i vendor/ruby/1.8 vendor/bundler*.gem
rake=/usr/bin/rake GEM_PATH=$PWD/vendor/ruby/1.8 PATH=$PATH:$PWD/vendor/ruby/1.8/bin bundle install --path vendor --local
