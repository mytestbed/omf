module OmfEc
  module GroupExt
    @@methods_to_fwd = []

    def fwd_method_to_aliases(*m)
      @@methods_to_fwd += m.flatten
    end

    def method_added(m)
      if @@methods_to_fwd.delete(m)
        alias_method "#{m}_without_fwd_to_aliases", m
        define_method m do |*args, &block|
          method("#{m}_without_fwd_to_aliases").call(*args, &block)
          self.g_aliases.each { |g| g.send(m, *args, &block) }
        end
      end
    end
  end
end
