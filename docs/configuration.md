Configuration
=============

Buffy is configured using a simple YAML file containing all the settings needed. The settings file is located in the `/config` dir and is named `settings-<environment>.yml`, where `<environment>` is the name of the environment Buffy is running in, usually set via the *RACK_ENV* env var. So for a Buffy instance running in production mode, the configuration file will be `/config/settings-production.yml`

A sample settings file will look similar to this:

```yaml
buffy:
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
    assign_reviewer_n:
      only: editors
    remove_reviewer_n:
      only: editors
      no_reviewer_text: "TBD"
    assign_editor:
      only: editors
    remove_editor:
      only: editors
      no_editor_text: "TBD"
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

## Available settings

The structure of the settings file starts with a single root node called `buffy`.
It contains three main parts:

  - A few simple key/value settings
  - The `teams` node
  - The `responders` node

A detailed description of all of them:

<dl>
  <dt>bot_github_user</dt>
  <dd>The name of the bot. It is the GitHub user that will respond to commands. It should have admin permissions on the reviews repo.</dd>

  <dt>gh_access_token</dt>
  <dd>The GitHub developer access token for the bot user.</dd>

  <dt>gh_secret_token</dt>
  <dd>The GitHub secret token configured for the webhook sending events to Buffy.</dd>
</dl>
