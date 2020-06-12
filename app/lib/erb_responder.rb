require 'erb'

module ERBResponder

  # Create a new comment in the issue rendering a .erb template.
  def respond_template(template_name, locals={})
    filename = "#{File.expand_path '../../responses', __FILE__}/#{template_name}.erb"
    template = ERB.new(File.read(filename))
    message = template.result_with_hash(locals)

    respond(message)
  end

  # Default location for templates in target repo
  # Can be overriden by setting: :template_path
  def default_template_path
    ".buffy/templates"
  end

  # Where the templates are located
  def template_path
    @template_path ||= @settings[:template_path] || default_template_path
    Pathname.new @template_path
  end

end
