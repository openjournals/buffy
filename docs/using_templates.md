Using templates
===============

Several Buffy responders can reply with a template. Please read each Responder documentation to know if a specific Responder allows this option.

## Template files

Templates must be created in the repository using Buffy. Every template is a different file in the repo. To make use of them Buffy needs to know where the templetes are located, and the individual name of each template file. As the comments in GitHub issues are rendered using markdown, usually the templates will be plain text or .md files, but that is not mandatory for Buffy to use them.

### Location

Buffy will look for the templates in the target repository. By default it will look under the `.buffy/templates` dir. This value can be modified in the settings file with the `templates_path` setting. If present, the value of this setting will be considered the relative value in the target repo where templates are located.


### Name

In the responders allowing templates for replies, the template is specified using the `template_file` setting for that responder.

### Example

If Buffy is configured to work on a repo with address _https://github.com/scientific-journal/astronomy_ and the _settings.yml_ file has the following value for _template_path_:

```yaml
buffy:
  templates_path: .templates
...
```

and you declare a template in a responder using _template_file_ with this value:
```yaml
...
responders:
  welcome_template:
    template_file: welcome.md
...
```

Buffy will use the content of _https://github.com/scientific-journal/astronomy/.templates/welcome.md_ to respond.