Authors check
=============

This responder compares (asynchronously) the list of authors in the paper with:

- the authors (creators) of the paper's Zenodo archive, and
- the contributors to the software's GitHub repository.

It replies with a table showing, for every author in the paper, whether they appear in the Zenodo archive and among the GitHub contributors. It also lists Zenodo authors and GitHub contributors who weren't matched to a paper author (a second account with exactly the same name as an author isn't listed).

Only the paper's metadata is downloaded from the repository, not the whole repository, so the check is quick even for big repositories. GitHub usernames are always shown as code (`` `@username` ``), so the reply doesn't notify anyone.

Names are matched leniently, so small differences are flagged rather than missed:

- **Zenodo:** ✅ means the name is written exactly the same way (Zenodo's `Last, First` format counts as the same as `First Last`). ⚠️ means it is probably the same person but the name is written differently: different accents or capitalization, a missing initial, a typo, or a different name with the same ORCID. It is also shown, with both ORCIDs, when the paper and Zenodo list different ORCIDs for the same name.
- **GitHub:** ✅ means the name in the contributor's GitHub profile matches. ⚠️ means it is probably the same person: a similar name, or a username built from the author's name (for example `jsmith` for John Smith) when the profile doesn't have a different name.

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

The Zenodo archive can be given in the command, as a DOI or a Zenodo record URL:
```
@botname check authors with archive 10.5281/zenodo.123456
@botname check authors with archive https://zenodo.org/records/123456
```

The paper's file can be given in the command, as its path in the repository. For a LaTeX paper, the authors are read from the `paper.yml` file next to it:
```
@botname check authors with paper docs/paper.md
```

These options can be used together, in any order.

## Requirements

The target repository should include a `paper.md` file (or a `paper.tex` file with a `paper.yml` metadata file next to it) with an `authors` list in its metadata. If there are several, the one closest to the root of the repository is used, unless a file is given with `with paper <path>`. Each author can have a `name`, or `given-names` and `surname` fields, and optionally an `orcid`. Authors can also be listed as plain names (`- Jane Doe`), and footnotes in names (`Jane Doe^[Corresponding author]`) are ignored.

The body of the issue should have the URL of the repository marked with HTML comments:

```html
<!--target-repository--> URL HERE <!--end-target-repository-->
```

The Zenodo archive is looked for in this order:

1. The archive given in the command (`with archive <DOI or URL>`).
2. The `archive` value in the body of the issue (set with `@botname set <DOI> as archive`).
3. The most recent issue comment that mentions a Zenodo DOI (like `10.5281/zenodo.123456`) or a Zenodo record URL. If a comment mentions several, the last one is used.

The bot's own comments are skipped. When the archive comes from a comment, the reply links to that comment, so the editor can check it's the right archive.

If the archive isn't given in the command, and the most recent `@botname set ... as archive` comment doesn't match the archive in the issue (for example because that command was refused), the bot doesn't guess: it replies with an error, linking to that comment, and asks the editor to set the right archive in the issue. A `set Pending as archive` command cancels the earlier ones.

Zenodo sandbox records are not checked.

If no archive is found, or it isn't in Zenodo, or the repository isn't on GitHub, that part of the check is skipped and the reply says so.

When the paper's file or the Zenodo archive can't be found or read, the reply says what went wrong and how to name it explicitly, e.g. `@botname check authors with paper <path to paper.md>` or `@botname check authors with archive <Zenodo DOI or URL>`.

## Settings key

`authors_check`

## Params
```eval_rst
:url_field: The optional name of the field marked with HTML comments where the URL of the repository with the paper is located. Default value is **target-repository**.
:branch_field: The optional name of the field marked with HTML comments where the name of the branch is located. Defaults to **branch**. If the setting is not present or the branch field is not found in the body of the issue, the default branch of the git repo will be used.
:archive_field: The optional name of the archive field, used to find `@botname set <DOI> as <archive_field>` comments and the value marked with HTML comments in the body of the issue. Default value is **archive**.
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
