Authors check
=============

This responder compares (asynchronously) the list of authors in the paper with:

- the authors (creators) of the paper's Zenodo archive, and
- the contributors to the software's GitHub repository.

It replies with a table showing, for every author in the paper, whether they appear in the Zenodo archive and among the GitHub contributors. It also lists Zenodo authors who aren't in the paper, and GitHub contributors who don't match any paper author.

Names are matched leniently, so small differences are flagged rather than missed:

- **Zenodo:** ✅ means the name is written exactly the same way (Zenodo's `Last, First` format counts as the same as `First Last`). ⚠️ means it is probably the same person but the name is written differently: different accents or capitalization, a missing initial, a typo, or a different name with the same ORCID.
- **GitHub:** ✅ means the name in the contributor's GitHub profile matches. ⚠️ means it is probably the same person: a similar name, or a username built from the author's name (for example `jsmith` for John Smith).

GitHub contributors are people who made commits, so authors who contributed in other ways won't be found there, and not every contributor has to be an author. The results are meant to help editors, not to pass or fail a submission.

Reviewers, the editor and bot accounts are left out of the GitHub contributors list. If a repository has more than 50 contributors, only the 50 with the most commits are checked.

## Listens to

```
@botname check authors
```

A non-default branch can be specified to look for the paper's files in it:
```
@botname check authors from branch <custom-branch-name>
```

## Requirements

The target repository should include a `paper.md` file (or a `paper.tex` file with a `paper.yml` metadata file) with an `authors` list in its metadata. Each author can have a `name`, or `given-names` and `surname` fields, and optionally an `orcid`.

The body of the issue should have the URL of the repository marked with HTML comments:

```html
<!--target-repository--> URL HERE <!--end-target-repository-->
```

To check the Zenodo authors, the issue should also include the archive's DOI (Zenodo DOIs look like `10.5281/zenodo.123456`):

```html
<!--archive--> DOI HERE <!--end-archive-->
```

If there is no archive, or it isn't in Zenodo, or the repository isn't on GitHub, that part of the check is skipped and the reply says so.

## Settings key

`authors_check`

## Params
```eval_rst
:url_field: The optional name of the field marked with HTML comments where the URL of the repository with the paper is located. Default value is **target-repository**.
:branch_field: The optional name of the field marked with HTML comments where the name of the branch is located. Defaults to **branch**. If the setting is not present or the branch field is not found in the body of the issue, the default branch of the git repo will be used.
:archive_field: The optional name of the field marked with HTML comments where the DOI of the archive is located. Default value is **archive**.
:ignored_users_fields: The optional list of fields marked with HTML comments that contain GitHub usernames to leave out of the contributors list. Default value is **[reviewers-list, editor]**.

```

## Examples

**Simplest case:**
```yaml
...
  authors_check:
...
```

**Customizing fields:**
```yaml
...
  authors_check:
    only: editors
    archive_field: zenodo-doi
    ignored_users_fields:
      - reviewers-list
      - editor
      - eic
...
```
