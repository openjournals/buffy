Check Zenodo DOI
================

This responder checks (asynchronously) that a Zenodo DOI is a **version DOI**, the DOI of one specific version of a record. It's meant for editors checking the archive of the software that was reviewed.

A **concept DOI** fails the check: it covers all versions of a record and always resolves to the latest one, so it won't keep pointing to the version that was reviewed. When that happens, the reply gives the DOI of the latest version.

The check also fails if no Zenodo record has the DOI. A version DOI that has a newer version passes, with a note. A DOI that isn't a Zenodo DOI is fine: there's nothing to check, and the reply says so.

## Listens to

```
@botname check zenodo doi <doi>
```

The DOI can be written as `10.5281/zenodo.123456`, `doi:10.5281/zenodo.123456` or `https://doi.org/10.5281/zenodo.123456`.

## Running it when the archive is set

The check can run automatically whenever editors set the archive, using the `run_responder` option of the [Set value responder](./set_value):

```yaml
...
  set_value:
    - archive:
        only: editors
        run_responder:
          responder_key: check_zenodo_doi
          message: "@{{bot_name}} check zenodo doi {{value}}"
  check_zenodo_doi:
...
```

Run this way, only Zenodo DOIs are checked. Any other archive (a figshare DOI, an OSF link, ...) gets no extra reply at all.

## Requirements

None. The responder uses Zenodo's public API, so it needs no token.

## Settings key

`check_zenodo_doi`

## Examples

**Simplest case:**
```yaml
...
  check_zenodo_doi:
...
```

**Only editors can run it:**
```yaml
...
  check_zenodo_doi:
    only: editors
...
```

## In action

A version DOI:
```
@botname check zenodo doi 10.5281/zenodo.11658941
```

> ✅ `10.5281/zenodo.11658941` is a version DOI (version `0.1.17`).

A concept DOI:
```
@botname check zenodo doi 10.5281/zenodo.11164917
```

> ❌ `10.5281/zenodo.11164917` is a concept DOI, not a version DOI. A concept DOI always resolves to the latest version of the record, so it won't keep pointing to the version that was reviewed.
>
> Please use the DOI of the reviewed version instead. The latest version's DOI is `10.5281/zenodo.11658941` (version `0.1.17`).
