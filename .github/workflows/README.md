# GitHub Actions workflows

This directory contains repository automation executed by GitHub Actions.
Workflow permissions should be kept minimal, third-party actions should be
pinned and reviewed, and secrets must be referenced through GitHub rather than
stored in the repository.

## Publishing the role

`tag.yml` creates a semantic-version tag after a successful push to `main`.
GitHub suppresses new push events produced with `GITHUB_TOKEN`, so the remaining
automation uses workflow-completion events: `release.yml` runs after `Tag`, and
`publish.yml` runs after `Release`.

`publish.yml` then re-imports this GitHub repository into Ansible Galaxy. This
repository is a role, not a collection, so it uses
`ansible-galaxy role import` and does not build a collection archive.

Sign in to [Ansible Galaxy](https://galaxy.ansible.com/) with the GitHub account
that owns this repository. Then open **Collections → API Token**, select
**Load Token**, and copy the Galaxy API key. In the GitHub repository, create an
environment named `ansible-galaxy` and add an environment secret named
`GALAXY_API_KEY`.

GitHub authentication associates the Galaxy account with repositories you can
access. The separate Galaxy API key is still required for non-interactive CLI
imports from GitHub Actions.
