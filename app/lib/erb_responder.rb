require 'erb'

module ERBResponder

  # Create a new comment in the issue rendering a .erb template.
  def respond_template(template_name, locals={})
    filename = "#{File.expand_path '../../responses', __FILE__}/#{template_name}.erb"
    template = ERB.new(File.read(filename))
    message = template.result_with_hash(locals)

    respond(message)
  end

end
