class Object
  def stub name, val_or_callable, &block
    new_name = "__minitest_stub__#{name}"
    metaclass = class << self; self; end
    metaclass.send :alias_method, new_name, name
    metaclass.send :define_method, name do |*args, &stub_block|
      if val_or_callable.respond_to? :call then
        val_or_callable.call(*args, &stub_block)
      else
        val_or_callable
      end
    end
    yield self
  ensure
    metaclass.send :undef_method, name
    metaclass.send :alias_method, name, new_name
    metaclass.send :undef_method, new_name
  end
end


