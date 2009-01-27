
module VisyoNet
  class CodeDataSource < DataSource
  
    def initialize(name = nil, root = nil)
      super(name, root)
      @procs = Hash.new
      if (root != nil)
        root.elements.each { |el|
          case el.name
          when "Code"
            name = el.attributes['id']
            if (name == nil)
              raise "Missing 'id' attribute in Code tag"
            end
            @procs[name] = toProc(el)
          else
            error("Unknown config tag '#{el.name}'")
          end
        }
      end
    end
    
    def toProc(el)
      s = ""
      el.children.each { |el|
        s += el.to_s
      }
      return Proc.new {|session| eval s}
    end
    
    
    def fetch(name, session, &block)
      if ((proc = @procs[name]) == nil)
        debug("Undefined code segment '#{name}'")
        return
      end
      
      names, rows = proc.call(session)
      rows.each { |row|
        yield(names, row)
      }
    end

  end # class
end # module