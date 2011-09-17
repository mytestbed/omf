
if $0 == __FILE__
  module OMF; module Common; end; end
end

module OMF::Common::YAML
  
  class YamlFileNotFound < Exception; end
  
  # A method to load YAML files
  #
  # file_name - Name of file to load 
  # opts - 
  # => :default - value to use if file can't be loaded
  # => :path - array of directories to look for file
  #
  # raise YamlFileNotFound if YAML file can't be found
  #
  def self.load(file_name, opts = {})
    if (file_name.split('.').length == 1)
      file_name = file_name + '.yaml'
    end

    path = opts[:path] || ['.', File.dirname(__FILE__)]
    begin
      path.each do |d|
        begin
          return _load_file(d + '/' + file_name)
        rescue YamlFileNotFound => ex
        end
      end
      if (default = opts[:default])
        return _symbolize(default)
      end
      raise YamlFileNotFound.new("Can't read YAML file '#{file_name}' in '#{path.join(':')}'")
    end
  end
  
  private

  def self._load_file(file, opts = {})
    begin
      begin
        require 'rbyaml'
        h = RbYAML::load_file(file)
      rescue LoadError => ex
        require 'yaml'
        h = YAML::load_file(file)
      end
    rescue Exception => ex
      unless (h = opts[:default])
        raise YamlFileNotFound.new("Can't read YAML file '#{file}'")
      end
    end
    _symbolize(h)
  end
  
  
  def self._symbolize(obj)
    if obj.kind_of? Hash
      res = {}
      obj.each do |k, v|
        if k.kind_of? String
          if k.start_with?(":")
            k = k[1 .. -1]
          end
          k = k.to_sym
        end
        res[k] = _symbolize(v)
      end
      return res
    elsif obj.kind_of? Array
      return obj.collect do |el|
        _symbolize(el)
      end
    else
      return obj
    end
  end    
end

if $0 == __FILE__
  h = OMF::Common::YAML.load 'foo'#, :default => {':foo' => {:goo=> 3}}
  puts h.inspect
  puts h.keys[0].class
  puts h[:foo].keys[0].class

  #puts OMF::Common::YAML.load('omf-expctl', :path => ['../../../omf-expctl/etc/omf-expctl']).inspect
  
end