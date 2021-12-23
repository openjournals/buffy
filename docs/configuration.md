Configuration
=============

Buffy is configured using a simple YAML file containing all the settings needed. The settings file is located in the `/config` dir and is named `settings-<environment>.yml`, where `<environment>` is the name of the environment Buffy is running in, usually set via the *RACK_ENV* env var. So for a Buffy instance running in production mode, the configuration file will be `/config/settings-production.yml`

A sample settings file will look similar to this:

```yaml
buffy:
  env:
    bot_github_user: <%= ENV['BUFFY_BOT_GH_USER'] %>
    gh_access_token: <%= ENV['BUFFY_GH_ACCESS_TOKEN'] %>
    gh_secret_token: <%= ENV['BUFFY_GH_SECRET_TOKEN'] %>
  teams:
    editors: 3824115
    eics: myorg/editor-in-chief-team
  responders:
    help:
    hello:
      hidden: true
    assign_editor:
      only: editors
    remove_editor:
      only: editors
      no_editor_text: "TBD"
    list_of_values:
      - reviewers:
          only: editors
          if:
            role_assigned: editor
            reject_msg: "Can't assign reviewer because there is no editor assigned for this submission yet"
          sample_value: "@username"
          add_as_assignee: true
    invite:
      only: eics
    set_value:
      - version:
          only: editors
          sample_value: "v1.0.0"
      - archive:
          only: editors
          sample_value: "10.21105/joss.12345"
    welcome:
```

## File Structure

The structure of the settings file starts with a single root node called `buffy`.
It contains three main parts:

  - The `env` node
  - The `teams` node
  - The `responders` node

A detailed description of all of them:

## Env: General configuration settings

```yaml
  env:
    bot_github_user: <%= ENV['BUFFY_BOT_GH_USER'] %>
    gh_access_token: <%= ENV['BUFFY_GH_ACCESS_TOKEN'] %>
    gh_secret_token: <%= ENV['BUFFY_GH_SECRET_TOKEN'] %>
    templates_path: ".templates"
```
The _env_ section is used to declare general key/value settings. For security reasons is a good practice to load the secret values from your environment instead of hardcoding them in the code.

<dl>
  <dt>bot_github_user</dt>
  <dd>The name of the bot. It is the GitHub user that will respond to commands. It should have admin permissions on the reviews repo. The default value is reading it from the <strong>BUFFY_BOT_GH_USER</strong> environment variable.</dd>

  <dt>gh_access_token</dt>
  <dd>The GitHub developer access token for the bot user. The default value is reading it from the <strong>BUFFY_GH_ACCESS_TOKEN</strong> environment variable.</dd>

  <dt>gh_secret_token</dt>
  <dd>The GitHub secret token configured for the webhook sending events to Buffy. The default value is reading it from the <strong>BUFFY_GH_SECRET_TOKEN</strong> environment variable.</dd>

  <dt>templates_path</dt>
  <dd>The relative path in the target repo where templates are located. This path is used by responders replying with a message built from a template. The default value is <code class="docutils literal"><span class="pre">.buffy/templates</span></code>.</dd>
</dl>

## Teams

```yaml
  teams:
    editors: 3824117
    eics: myorg/editor-in-chief-team
    reviewers: 45363564
    collaborators:
      - user33
      - user42
```
 The optional teams node includes entries to reference GitHub teams, used later to grant access to responders only to users belonging to specific teams. The teams referred here must be __visible__ teams of the organization owner of the repositories where the reviews will take place. Multiple entries can be added to the teams node. All entries follow this simple format:

 <dl>
  <dt>key: value</dt>
  <dd>Where <em>key</em> is the name for this team in Buffy and <em>value</em> can be:
    <dl>
      <dd>- The integer <strong>id of the team</strong> in GitHub (preferred)</dd>
      <dd>- The <strong>reference</strong> in format <em>organization/name</em> (for example: <em>openjournals/editors</em>)</dd>
      <dd>- An array of user handles</dd>
    </dl>
  </dd>
</dl>

## Responders

```yaml
  responders:
    help:
    hello:
      hidden: true
    assign_reviewers:
      only: editors
```

 The responders node lists all the responders that will be available. The key for each entry is the name of the responder and nested under it the configuration options for that responder are declared.

### Common options

 All the responders share some options available to all of them. They can also have their own particular configurable parameters (see [docs for each responder](./available_responders)). The common parameters are:

<dl>
  <dt>hidden</dt>
  <dd>Defaults to <em>false</em>. If <em>true</em> this responder won't be listed in the help provided to users.

  Usage:

  ```yaml
    ...
    secret_responder:
      hidden: true
    ...

  ```
  </dd>

  <dt>only</dt>
  <dd>List of teams (referred by the name used in the <em>teams</em> node) that can have access to the responder. Used to limit access to the responder. If <em>only</em> is not present the responder is considered public and every user in the repository can invoke it.

  Usage:

  ```yaml
    public_responder:
    available_for_one_team_responder:
      only: editors
    available_for_two_teams_responder:
      only:
        - editors
        - reviewers
  ```

  </dd>

  <dt>if</dt>
  <dd>This setting is used to impose conditions on the responder. It can include several options:

```eval_rst
:title: *<String>* or *<Regular Expresion>* Responder will run only if issue' title matches this.
:body: *<String>* or *<Regular Expresion>* Responder will run only if the body of the issue matches this.
:value_exists: *<String>* Responder will run only if there is a not empty value for this in the issue (marked with HTML comments).
:value_matches: *<Hash>* Responder will run only if the param values (marked with HTML comments) in the body of the issue matches the ones specified here.
:role_assigned: *<String>* Responder will be run only if there is a username assigned for the specified value.
:reject_msg: *<String>* Optional. The response to send as comment if the conditions are not met
```

  Usage:

  ```yaml
    # This responder should be invoked only if there's an editor assigned
    # otherwise will reply with a custom "no editor assigned yet" message
    assign_reviewer:
      if:
        role_assigned: editor
        reject_msg: I can not do that because there is no editor assigned yet

    # This responder will run only if issue title includes '[PRE-REVIEW]' and if
    # there is a value for repo-url, ie: <!--repo-url-->whatever<!--end-repo-url-->
    start_review:
      if:
        title: "^\\[PRE-REVIEW\\]"
        value_exists: repo-url

    # This responder will run only if the value for submission_type in the body of
    # the issue matches 'astro', ie: <!--submission_type-->astro<!--end-submission_type-->
    start_review:
      if:
        value_matches:
          submission_type: astro
  ```
  </dd>

</dl>

A complete example:

```yaml
  # Two responders are configured here:
  #
  # The assign_reviewers responder will respond only when triggered by a user that is
  # member of any of the editors or editors-in-chief teams. It will also respond only
  # in issues with the text "[REVIEW]" in its title and that have a not empty value
  # in its body marked with HTML comments: <!--editor-->@EDITOR_HANDLE<!--end-editor-->
  # Once invoked, it will label the issue with the 'reviewers-assigned' label.
  #
  # The hello responder is configured as hidden, so when calling the help responder the
  # description and usage example of the hello responder won't be listed in the response.
  ...
  responders:
    assign_reviewers:
      only:
        - editors
        - editors-in-chief
      if:
        title: "^\\[REVIEW\\]"
        role_assigned: editor
      add_labels:
        - reviewers-assigned
    hello:
      hidden: true
  ...
```
Several responders also allow [adding or removing labels](./labeling).

### Multiple instances of the same responder

Sometimes you want to use a responder more than once, with different parameters. In that case under the name of the responder you can declare an array of instances, and the key for each instance will be passed to the responder as the `name` parameter.

Example:

The _set_value_ responder uses a `name` param to change the value to a variable. If declared in the settings file like this:


```yaml
  responders:
    set_value:
      name: version
```

It could be invoked with `@botname set 1.0 as version`.

If you want to use the same responder to change `version` but also to allow editors to change `url` you would declare multiple instances in the settings file like this:

```yaml
  responders:
    set_value:
      - version:
      - url:
          only: editors
```

Now `@botname set 1.0 as version` is a public command and `@botname set abcd.efg as url` is a command available to editors.

