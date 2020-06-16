require 'erb'
require 'open-uri'

module Templating

  # Create a new comment in the issue rendering a .erb template.
  def respond_template(template_name, locals={})
    filename = "#{File.expand_path '../../responses', __FILE__}/#{template_name}.erb"
    template = ERB.new(File.read(filename))
    message = template.result_with_hash(locals)

    respond(message)
  end

  # Create a new comment in the issue rendering an external template.
  def respond_external_template(template_file, locals={})
    template = URI.parse(template_url(template_file)).read
    message = apply_hash_to_template(template, locals)

    respond(message)
  end

  # Default location for templates in target repo
  # Can be overriden by setting: :template_path
  def default_template_path
    ".buffy/templates"
  end

  # Where the templates are located.
  def template_path
    @template_path ||= @settings[:template_path] || default_template_path
    Pathname.new @template_path
  end

  # Replace variable placeholders {{varname}} with values from a hash.
  def apply_hash_to_template(template, locals)
    locals.each_pair { |k, v| template.gsub! /{{#{k}}}/i, v.to_s}
    template
  end

end
