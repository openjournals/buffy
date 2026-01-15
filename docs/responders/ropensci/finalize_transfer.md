ROpenSci :: Finalize transfer
=============================

This responder is used to assign a recently approved and transferred package to an rOpenSci team. It needs owner rights to work.
It performs a series of tasks:

- Checks for the presence of the package-name repo in the rOpenSci GitHub organization
- Creates a new team named like the package-name and invites the creator of the issue to it, if the team does not exists already.
- Adds the package-name repo to the package-name team with admin rights so the members of the team can manage it

## Listens to

```
@botname finalize transfer of package-name
```

## Requirements

The _package-name_ must be specified in the command, otherwise an error message will be sent as reply.
The bot must have owner rights.

## Settings key

`ropensci_finalize_transfer`

## Example:

```yaml
...
  responders:
    ropensci_finalize_transfer:
      only: editors
...
```
