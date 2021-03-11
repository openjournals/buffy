Using templates
===============

Several Buffy responders can reply with a template. Please read each Responder documentation to know if a specific Responder allows this option.

## Template files

Templates must be created in the repository using Buffy. Every template is a different file in the repo. To make use of them Buffy needs to know where the templates are located, and the individual name of each template file. As the comments in GitHub issues are rendered using markdown, usually the templates will be plain text or .md files, but that is not mandatory for Buffy to use them.

### Location

Buffy will look for the templates in the target repository. By default it will look under the `.buffy/templates` dir. This value can be modified in the settings file with the `templates_path` setting. If present, the value of this setting will be considered the relative value in the target repo where templates are located.


### Name

In the responders allowing templates for replies, the template is specified using the `template_file` setting for that responder. Value should be the name of the file including the extension if it has one.

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

## Populating templates

The content of a template can include placeholders to be filled with the actual values of a variable. The syntax is:
```
{{variable_name}}
```

When rendering a template, Buffy will use a hash of `key:value` pairs. When a placeholder is found in the template, it will look up for the corresponding key in the hash and insert the value in the template. The hash will always include _at least_:
- **issue_id**: The id of the issue
- **issue_author**: The handle of the user that opened the issue
- **repo**: the name of the repository
- **sender**: the handle of the user creating the comment/issue triggering the responder
- **bot_name**: the name of the bot user responding

The hash can also include fields extracted from the body of the issue. To add fields use the `data_from_issue` setting. For example, to have the `target-repository` and `author` values from the issue available in the template this would do:
```yaml
...
responders:
  welcome_template:
    template_file: welcome.md
    data_from_issue:
        - target-repository
        - author
...
```

Check each responder documentation for details on other values available to use in templates.
