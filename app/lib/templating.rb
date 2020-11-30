require 'erb'
require 'open-uri'

module Templating

  # Create a new comment in the issue rendering a .erb template.
  def respond_template(template_name, locals={})
    filename = "#{File.expand_path '../../responses', __FILE__}/#{template_name}.erb"
    template = ERB.new(File.read(filename), trim_mode: '-')
    message = template.result_with_hash(locals)

    respond(message)
  end

  # Create a new comment in the issue rendering an external template.
  def respond_external_template(template_file, locals={})
    respond render_external_template(template_file, locals)
  end

  # Renders an external template using the passed locals
  def render_external_template(template_file, locals={})
    template = URI.parse(template_url(template_file)).read
    apply_hash_to_template(template, locals)
  end

  # Where the templates are located.
  def template_path
    @template_path ||= @env[:templates_path] || default_settings[:templates_path]
    Pathname.new @template_path
  end

  # Replace variable placeholders {{varname}} with values from a hash.
  def apply_hash_to_template(template, locals)
    locals.each_pair { |k, v| template.gsub! /{{#{k}}}/i, v.to_s}
    template
  end

end
