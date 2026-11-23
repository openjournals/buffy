Check Zenodo DOI
================

This responder checks (asynchronously) that a Zenodo DOI is a **version DOI**, the DOI of one specific version of a record. It's meant for editors checking the archive of the software that was reviewed.

A **concept DOI** fails the check: it covers all versions of a record and always resolves to the latest one, so it won't keep pointing to the version that was reviewed. When that happens, the reply gives the DOI of the latest version.

The check also fails if the DOI isn't a Zenodo DOI or no Zenodo record has it. A version DOI that has a newer version passes, with a note.

## Listens to

```
@botname check zenodo doi <doi>
```

The DOI can be written as `10.5281/zenodo.123456`, `doi:10.5281/zenodo.123456` or `https://doi.org/10.5281/zenodo.123456`.

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
