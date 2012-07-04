class YardExtension < YARD::Handlers::Ruby::Base
  handles method_call(:hook)
  handles method_call(:configure)
  handles method_call(:request)
  namespace_only

  def process
    name = statement.parameters.first.jump(:tstring_content, :ident).source
    object = YARD::CodeObjects::MethodObject.new(namespace, "#{statement.method_name.source} -> #{name}")
    register(object)
    parse_block(statement.last.last, :owner => object)
    object.dynamic = true
  end
end

