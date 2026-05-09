# DTAP branching & promotion

This repository uses **DTAP** (Development, Test, Acceptance, Production) with **long-lived environment branches** and **PR-based promotion**.

## Branches

- **Development (D)**: `dev`
  - Day-to-day integration branch for feature work.
- **Test (T)**: `test`
  - Represents what is deployed to the test environment.
- **Acceptance (A / UAT)**: `acceptance`
  - Represents what is deployed to the acceptance/UAT environment.
- **Production (P)**: `main`
  - Represents what is deployed to production.

## Promotion flow

Changes move “up” the environments only via pull request:

`dev` → `test` → `acceptance` → `main`

Rules:

- Promotion PRs should be **merge commits disabled** (squash or rebase is fine) to keep history clean.
- Hotfixes can be branched off `main` and promoted back down to `dev` after release (see below).

## Branch protection (recommended)

Configure GitHub branch protections:

- **Require status checks**: CI workflow must pass before merge
- **Require PR reviews**: at least 1 approval (more for `main`)
- **Restrict direct pushes**: no direct pushes to `test`, `acceptance`, `main` (optionally also `dev`)

## Release tags

Production releases are created by tagging `main` with a semantic version:

- Example: `v0.1.0`, `v1.2.3`

Pushing a `v*` tag triggers the release workflow, which:

- runs tests
- creates a GitHub Release

## Hotfix flow (when needed)

- Branch from `main`: `hotfix/<name>`
- PR `hotfix/<name>` → `main`
- Tag the merge commit on `main` (e.g. `v1.2.4`)
- Backport by promoting `main` down:
  - PR `main` → `acceptance`, then `acceptance` → `test`, then `test` → `dev`

