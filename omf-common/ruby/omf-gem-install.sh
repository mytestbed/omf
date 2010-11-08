echo "Installing bundler gem"
gem install --no-ri --no-rdoc -l -i vendor/ruby/1.8 vendor/cache/bundler*.gem
PATH=$PATH:$PWD/vendor/ruby/1.8/bin bundle install --path vendor --local
