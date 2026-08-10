# Forgejo-Canonical Homebrew Tap Design

Date: 2026-08-10

## Goal

Make `https://git.m0sh1.cc/isityael/tap` the canonical repository for source code, repository history, pull requests, Renovate changes, Woodpecker pipelines, tags, and releases. Keep `https://github.com/isityael/tap` as a public Git mirror and duplicate release-asset host.

The migration must preserve the existing GitHub issue and pull-request history. Existing Homebrew installations using the historical `yaelmoshi/tap` name must continue updating.

## Current State

- The local repository has only `https://github.com/isityael/tap.git` configured as `origin`.
- `https://git.m0sh1.cc/isityael/tap` does not exist.
- Woodpecker repository 11 watches the GitHub repository.
- The GitHub repository has the `managed-by-renovate` topic and is processed by the GitHub Renovate job.
- The infrastructure already runs a separate Forgejo Renovate job that discovers Forgejo repositories with the `managed-by-renovate` topic.
- Woodpecker is already configured with the Forgejo driver and supports Forgejo push, pull-request, tag, and release events.
- The tap contains four Woodpecker pipelines. Several still clone or push the historical `github.com/yaelmoshi/tap` URL.
- The bottle workflow currently attempts to create a GitHub release and push the generated formula commit to GitHub.

## Chosen Architecture

The repository and automation flow will be:

```text
Developers and Renovate
          |
          v
Forgejo pull requests
          |
          v
Woodpecker validation
          |
          v
Forgejo main and tags
          |
          +----------------------+
          |                      |
          v                      v
Forgejo releases        Forgejo push mirror
                                 |
                                 v
                       GitHub Git mirror and
                       duplicate release assets
```

Forgejo is the only repository that accepts normal development, Renovate, checksum, and bottle-formula writes. GitHub receives Git refs from Forgejo's push-mirror facility. Woodpecker may write duplicate release assets to GitHub only after verifying that the corresponding Forgejo tag has been mirrored at the identical commit.

## Repository Migration

Use the authenticated `fj` CLI to migrate the GitHub repository into a normal Forgejo repository:

- Source: `https://github.com/isityael/tap`
- Destination: `isityael/tap` on `git.m0sh1.cc`
- Service type: GitHub
- Included data: Git data, issues, pull requests, labels, milestones, releases, wiki, and LFS where present
- Mirror flag: disabled
- Visibility: public
- Default branch: `main`

The migration must use a GitHub token through standard input without printing or persisting it in the repository.

After migration, compare the source and destination default branch, branch refs, tags, issue state, and pull-request history. The current GitHub repository has no open pull requests and has one open issue, the Renovate Dependency Dashboard. The migration must retain the historical pull requests as repository history.

## Push Mirror

Configure a Forgejo push mirror from `https://git.m0sh1.cc/isityael/tap` to `https://github.com/isityael/tap.git`.

`fj` version 0.6.0 can migrate repositories and manage releases but cannot create a new push mirror. Use Forgejo's authenticated repository API for this one operation. The credential must be a GitHub fine-grained token limited to `isityael/tap` with repository contents write permission.

The push mirror must:

- synchronize on new Forgejo pushes;
- include branches and tags;
- prune destination refs removed from the canonical repository;
- never pull GitHub changes back into Forgejo;
- be tested by comparing the exact `main` and testable tag commit IDs on both hosts.

GitHub remains public and unarchived because archiving would prevent the push mirror. Its description and repository documentation must identify it as a mirror and direct contributions to Forgejo.

## Local Remote Topology

After the Forgejo repository and push mirror pass validation, configure the local checkout as:

```text
origin  -> https://git.m0sh1.cc/isityael/tap.git
github  -> https://github.com/isityael/tap.git
```

The `main` branch tracks `origin/main`. Normal pushes use `origin`. The `github` remote is retained for read-only verification and emergency diagnostics, not routine publishing.

## Renovate Cutover

The existing Forgejo Renovate job becomes the sole Renovate owner:

1. Add the `managed-by-renovate` topic to the Forgejo repository.
2. Verify that `renovate-forgejo` discovers and extracts `isityael/tap` successfully.
3. Confirm that the Forgejo Dependency Dashboard exists and that Renovate branches and pull requests target Forgejo.
4. Remove `managed-by-renovate` from the GitHub repository.
5. Confirm that the GitHub Renovate job no longer discovers the mirror.

The repository's shared preset remains `local>isityael/infra//.github/renovate/base.json`, which resolves against the canonical Forgejo repository family.

Correct the contradictory Headlamp package rule in `renovate.json` by retaining `"enabled": true` and changing its description to state that Headlamp updates remain enabled. Recent successful Renovate updates through version 0.44.0 establish the active behavior; the stale description must not disable those updates.

## Woodpecker Cutover

Activate the Forgejo repository in Woodpecker before retiring repository 11.

The new Woodpecker repository must receive only the secrets required by its pipelines:

- a repository-scoped Forgejo bot token for checksum commits, formula commits, tags, and Forgejo releases;
- a GitHub token limited to duplicate release publication for `isityael/tap`;
- the existing macOS builder SSH key.

The old GitHub-backed Woodpecker repository remains active until the Forgejo webhook, configuration fetch, clone, manual pipelines, and pull-request pipeline have been validated. It is then deactivated or removed to prevent duplicate builds and webhooks.

The `.ci/test-woodpecker-lint.sh` contract must be executed by Woodpecker so it protects the lint scope rather than existing only as an uncalled local script.

## Pipeline Repository Writes

All pipeline Git writes target Forgejo.

- The checksum pipeline pushes updated Renovate branches back to Forgejo.
- The macOS test pipeline clones the exact Forgejo commit or Forgejo pull-request ref.
- The bottle pipeline clones the exact Forgejo commit and returns generated outputs to the Woodpecker workspace.
- No pipeline sets its primary Git remote to GitHub.

Credentials must be passed as Woodpecker secrets, must not be echoed, and must not be embedded in committed files. Commands must avoid shell tracing while credential-bearing URLs are in scope.

## Bottle Build and Dual Release Publication

Refactor bottle handling into build and publication responsibilities.

### Build phase

1. Woodpecker sends the exact Forgejo commit identifier to the macOS builder.
2. The builder clones Forgejo and checks out that exact commit.
3. The builder creates the ARM64 bottle and bottle JSON.
4. The generated bottle, JSON, and updated formula are returned to the Woodpecker workspace.
5. The builder removes its temporary checkout and artifacts after transfer.

### Canonical commit and tag phase

1. Woodpecker validates the generated formula diff and bottle asset.
2. Woodpecker commits the bottle block to Forgejo `main` with the CI identity.
3. Woodpecker creates the canonical `fast-cli-<version>` tag at that resulting commit and pushes it to Forgejo.
4. Woodpecker verifies that Forgejo resolves the tag to the expected commit.
5. Woodpecker waits for the Forgejo push mirror and verifies that GitHub resolves the same tag to the same commit.

The release process stops if either forge resolves the tag differently.

### Release phase

1. Use `fj release create` to create the canonical Forgejo release and attach the bottle.
2. Use `gh release create --verify-tag` to create the duplicate GitHub release and attach the identical bottle.
3. Verify release metadata, asset name, size, and SHA-256 digest on both platforms.

The Homebrew bottle root URL remains on GitHub for public download availability. Forgejo holds an identical canonical release asset so GitHub is not the only retained copy.

Release publication must be idempotent. A retry may complete a missing destination when the existing tag and asset digest match, but it must fail rather than overwrite an existing release or asset with different content.

## Homebrew Compatibility and Documentation

Existing installations under `yaelmoshi/tap` already have a custom remote pointing to `https://github.com/isityael/tap.git`; they must continue updating through the GitHub mirror.

For new installations, documentation must use the current identity and an explicit URL because the repository is named `tap` rather than the conventional `homebrew-tap`:

```sh
brew tap isityael/tap https://github.com/isityael/tap.git
```

The README must state:

- Forgejo is canonical for source, issues, and pull requests;
- GitHub is a read-only code mirror and public asset endpoint;
- the supported explicit `brew tap` command;
- existing `yaelmoshi/tap` installations remain supported.

Renaming the repository to `homebrew-tap` is outside this migration because it would add an independent compatibility change.

## Failure Handling and Cutover Order

The cutover is deliberately staged:

1. Migrate into Forgejo without changing current automation.
2. Validate imported history and refs.
3. Configure and validate the GitHub push mirror.
4. Update and validate repository pipelines locally.
5. Activate and validate the Forgejo Woodpecker repository.
6. Enable and validate Forgejo Renovate ownership.
7. Change the local canonical remote.
8. Remove GitHub Renovate discovery.
9. Retire the GitHub-backed Woodpecker repository.

Until step 8, GitHub remains the working fallback. No GitHub repository, issue, pull request, branch, tag, or historical release is deleted during migration.

If a migration or activation step fails, stop at that boundary, retain the previous automation owner, and correct the fault before continuing. Do not create empty commits or bypass failed checks to trigger automation.

## Verification

The migration is complete only when all applicable checks pass:

- local working tree remains free of unrelated changes;
- Forgejo contains the imported Git history, issues, pull requests, and labels;
- Forgejo is a normal repository rather than a pull mirror;
- Forgejo and GitHub `main` resolve to the same commit after mirror synchronization;
- GitHub cannot create a competing Renovate PR because its discovery topic is removed;
- Forgejo Renovate creates or updates its Dependency Dashboard without package lookup failures;
- the Forgejo Woodpecker mapping receives push and pull-request webhooks;
- all `.woodpecker/*.yaml` files pass `woodpecker-cli lint`;
- the Woodpecker lint contract executes in CI;
- shell scripts pass ShellCheck at error severity;
- all formula and cask files pass Ruby syntax validation and Homebrew style checks;
- macOS formula tests clone and test the Forgejo commit;
- a real future bottle release produces identical tag commits and asset digests on Forgejo and GitHub.

The dual release path is considered provisioned before the next upstream `fast-cli` version, but its final production proof is the first real bottle release after cutover. No fake public release or tag is created solely for testing.

## Security Boundaries

- Migration credentials are supplied through standard input and never committed.
- Forgejo and GitHub publication use separate least-privilege tokens.
- The GitHub mirror token is scoped only to `isityael/tap`.
- Woodpecker secrets are transferred without exposing their values.
- Forgejo remains the only destination for development and automation Git writes.
- No Kubernetes API write is required for this migration.
- Any required persistent Woodpecker or Renovate configuration change follows the existing GitOps path where it is repository-managed.
