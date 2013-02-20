class YardExtension < YARD::Handlers::Ruby::Base
  handles method_call(:hook)
  handles method_call(:configure)
  handles method_call(:request)
  handles method_call(:work)
  namespace_only

  def process
    name = statement.parameters.first.jump(:tstring_content, :ident).source
    case statement.method_name.source.to_sym
    when :hook, :work
      object = YARD::CodeObjects::MethodObject.new(namespace, "#{name}")
    when :configure, :request
      object = YARD::CodeObjects::MethodObject.new(namespace, "#{statement.method_name.source}_#{name}")
    end
    register(object)
    parse_block(statement.last.last, :owner => object)
    object.dynamic = true
  end
end

