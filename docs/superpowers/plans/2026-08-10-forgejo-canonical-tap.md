# Forgejo-Canonical Homebrew Tap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the complete Homebrew tap repository record and all active automation to Forgejo while retaining GitHub as a Git mirror and duplicate bottle-release host.

**Architecture:** Import GitHub into a normal Forgejo repository with `fj`, configure a Forgejo-owned push mirror to GitHub, then move Renovate and Woodpecker ownership to Forgejo. Repository contract tests enforce canonical URLs and dual-release behavior before live automation is switched.

**Tech Stack:** Git, Forgejo 16 API, `fj` 0.6.0, GitHub CLI, Woodpecker 3, Renovate Operator, Bash, Homebrew, Ruby.

## Global Constraints

- Forgejo owns source, issues, pull requests, tags, releases, Renovate, and Woodpecker.
- GitHub receives Git refs only through the Forgejo push mirror and duplicate release assets through Woodpecker.
- Import Git history, issues, pull requests, labels, milestones, releases, wiki, and LFS where present.
- Existing `yaelmoshi/tap` installations must keep updating.
- New installations use `brew tap isityael/tap https://github.com/isityael/tap.git`.
- Never print or commit Forgejo, GitHub, Woodpecker, or SSH credentials.
- Never create a fake public release or tag for testing.
- Preserve unrelated working-tree changes.

---

### Task 1: Canonical Repository Contract

**Files:**
- Create: `.ci/test-forgejo-canonical.sh`
- Modify: `.woodpecker/lint.yaml`
- Modify: `.woodpecker/checksums.yaml`
- Modify: `.woodpecker/test.yaml`
- Modify: `renovate.json`
- Modify: `README.md`

**Interfaces:**
- Consumes: Canonical repository URL `https://git.m0sh1.cc/isityael/tap.git` and GitHub distribution URL `https://github.com/isityael/tap.git`.
- Produces: A static contract test executed locally and in Woodpecker that rejects legacy pipeline writes and duplicate Renovate ownership.

- [ ] **Step 1: Write the failing repository contract test**

Create `.ci/test-forgejo-canonical.sh` with Arrange-Act-Assert checks that require:

```sh
grep -Fq 'sh .ci/test-woodpecker-lint.sh' .woodpecker/lint.yaml
grep -Fq 'sh .ci/test-forgejo-canonical.sh' .woodpecker/lint.yaml
grep -Fq 'https://git.m0sh1.cc/isityael/tap.git' .woodpecker/checksums.yaml
grep -Fq 'https://git.m0sh1.cc/isityael/tap.git' .woodpecker/test.yaml
! grep -F 'github.com/yaelmoshi/tap' .woodpecker/checksums.yaml .woodpecker/test.yaml README.md
grep -Fq '"enabled": true' renovate.json
grep -Fq 'Keep Headlamp updates enabled' renovate.json
grep -Fq 'brew tap isityael/tap https://github.com/isityael/tap.git' README.md
```

The script must aggregate failures, print a concise summary, and exit nonzero when any contract is violated.

- [ ] **Step 2: Run the contract and verify RED**

Run: `sh .ci/test-forgejo-canonical.sh`

Expected: FAIL because the Woodpecker pipelines still use GitHub or legacy URLs and the README lacks the canonical topology.

- [ ] **Step 3: Update repository configuration and documentation**

Apply the smallest changes that satisfy the contract:

- run both `.ci` contract scripts from `.woodpecker/lint.yaml`;
- make checksum pushes and macOS clones target Forgejo;
- retain the GitHub token only where duplicate release publication needs it;
- change the Headlamp rule description while retaining `"enabled": true`;
- document Forgejo canonical ownership, GitHub mirroring, the explicit new install command, and historical-name compatibility.

- [ ] **Step 4: Verify GREEN and lint**

Run:

```sh
sh .ci/test-forgejo-canonical.sh
sh .ci/test-woodpecker-lint.sh
woodpecker-cli lint .woodpecker/*.yaml
shellcheck -S error .ci/*.sh Scripts/*.sh
for file in Formula/*.rb Casks/*.rb; do ruby -c "$file"; done
```

Expected: all commands succeed.

- [ ] **Step 5: Commit the canonical repository contract**

```sh
git add .ci/test-forgejo-canonical.sh .woodpecker/lint.yaml .woodpecker/checksums.yaml .woodpecker/test.yaml renovate.json README.md
git commit -m "ci: make Forgejo canonical for tap automation"
```

### Task 2: Idempotent Dual Bottle Publication

**Files:**
- Create: `.ci/test-publish-bottle.sh`
- Create: `Scripts/publish-bottle.sh`
- Modify: `Scripts/bottle-arm.sh`
- Modify: `.woodpecker/bottle.yaml`

**Interfaces:**
- Consumes: `BOTTLE_FILE`, `BOTTLE_JSON`, `VERSION`, `EXPECTED_COMMIT`, `FORGEJO_TOKEN`, and `GITHUB_TOKEN`.
- Produces: `Scripts/publish-bottle.sh`, which commits the bottle block to Forgejo, creates a canonical tag and Forgejo release, waits for the mirror, and creates an identical GitHub release.

- [ ] **Step 1: Write failing dual-publication tests**

Create `.ci/test-publish-bottle.sh` with isolated fake `git`, `fj`, `gh`, and `sha256sum` executables in a temporary `PATH`. Test these behaviors with Arrange-Act-Assert functions:

1. missing required environment exits nonzero;
2. a Forgejo/GitHub tag mismatch exits before either release command;
3. matching tags call `fj release create` before `gh release create`;
4. existing matching releases are accepted without overwriting assets;
5. an existing asset with a different digest exits nonzero;
6. credentials never appear in captured standard output or standard error;
7. the full fake publication path completes in less than five seconds.

- [ ] **Step 2: Run the publication tests and verify RED**

Run: `bash .ci/test-publish-bottle.sh`

Expected: FAIL because `Scripts/publish-bottle.sh` does not exist.

- [ ] **Step 3: Implement the publication script**

Implement `Scripts/publish-bottle.sh` with these exact boundaries:

```text
validate inputs
validate bottle and JSON files
commit the generated formula change to Forgejo main
create fast-cli-VERSION tag at the resulting commit
push main and tag only to Forgejo
poll GitHub tag for at most 120 seconds in 5-second intervals
require Forgejo and GitHub tag commits to equal the local tagged commit
create or verify the Forgejo release with fj
create or verify the GitHub release with gh --verify-tag
compare remote asset name, size, and SHA-256 digest
```

Do not enable shell tracing. Pass credentials through process environment and credential helpers without echoing credential-bearing remote URLs.

- [ ] **Step 4: Make the macOS script build-only**

Change `Scripts/bottle-arm.sh` so it builds the bottle and JSON into an output directory supplied as its second argument. It must not create releases, tags, commits, or pushes. Keep the GitHub bottle root URL for public downloads.

- [ ] **Step 5: Connect build and publication in Woodpecker**

Update `.woodpecker/bottle.yaml` to:

- clone the exact Forgejo commit on the macOS builder;
- copy the bottle, JSON, and modified formula back with `scp`;
- run `Scripts/publish-bottle.sh` in the Woodpecker workspace;
- obtain Forgejo and GitHub tokens from distinct repository secrets;
- keep the macOS SSH key as a repository secret.

- [ ] **Step 6: Verify GREEN and all shell paths**

Run:

```sh
bash .ci/test-publish-bottle.sh
sh .ci/test-forgejo-canonical.sh
woodpecker-cli lint .woodpecker/*.yaml
shellcheck -S error .ci/*.sh Scripts/*.sh
```

Expected: all commands succeed and publication tests exercise every branch in `Scripts/publish-bottle.sh`.

- [ ] **Step 7: Commit dual publication**

```sh
git add .ci/test-publish-bottle.sh Scripts/publish-bottle.sh Scripts/bottle-arm.sh .woodpecker/bottle.yaml
git commit -m "ci: publish tap bottles from Forgejo to both forges"
```

### Task 3: Full Forgejo Migration and Push Mirror

**Files:**
- No repository files modified.
- External state: Forgejo repository, imported issue/PR history, push mirror, local Git remotes.

**Interfaces:**
- Consumes: authenticated `fj` and `gh` sessions without displaying tokens.
- Produces: normal public Forgejo repository `isityael/tap`, Forgejo-to-GitHub push mirror, local `origin` and `github` remotes.

- [ ] **Step 1: Capture immutable source evidence**

Record GitHub `main`, branch refs, tags, open issues, open PRs, and historical PR count using `git ls-remote` and `gh api`. Store only non-secret IDs in a temporary directory created by `mktemp -d`.

- [ ] **Step 2: Migrate all repository data with fj**

Pipe the authenticated GitHub token directly into:

```sh
fj repo migrate -H git.m0sh1.cc --service github --include all --token \
  https://github.com/isityael/tap.git isityael/tap
```

Do not pass `--mirror`.

- [ ] **Step 3: Verify imported data before pushing local commits**

Require Forgejo to be public and non-mirror, with `main` equal to the captured GitHub commit. Compare branch and tag refs and confirm issue/PR history exists through the Forgejo API.

- [ ] **Step 4: Configure the Forgejo push mirror**

Use the authenticated Forgejo API `POST /repos/isityael/tap/push_mirrors` with a GitHub repository-scoped token. Enable synchronization on commit push and pruning. Trigger `/repos/isityael/tap/push_mirrors-sync`, then require both forges to resolve `main` identically.

- [ ] **Step 5: Switch local remotes and publish local commits**

```sh
git remote rename origin github
git remote add origin https://git.m0sh1.cc/isityael/tap.git
git branch --set-upstream-to=origin/main main
git push origin main
```

Wait for the mirror and require `origin/main`, `github/main`, and local `main` to resolve to the same commit.

### Task 4: Renovate and Woodpecker Cutover

**Files:**
- No plaintext secret files.
- External state: Forgejo/GitHub topics and descriptions, Woodpecker repository mappings and secrets.

**Interfaces:**
- Consumes: working Forgejo repository and mirror from Task 3; passing pipelines from Tasks 1 and 2.
- Produces: Forgejo-only Renovate ownership and Forgejo-backed Woodpecker execution.

- [ ] **Step 1: Mark Forgejo canonical without disabling GitHub automation yet**

Set the Forgejo description to identify it as canonical and add `managed-by-renovate`. Update the GitHub description to identify it as a mirror while temporarily retaining its Renovate topic.

- [ ] **Step 2: Activate the Forgejo repository in Woodpecker**

Synchronize the Woodpecker repository list, add the Forgejo `isityael/tap` mapping, and verify its forge URL is `https://git.m0sh1.cc/isityael/tap`. Add the scoped Forgejo token, scoped GitHub token, and macOS builder SSH key without printing values.

- [ ] **Step 3: Validate Forgejo Woodpecker execution**

Run the lint workflow manually and require success. Verify the webhook exists in Forgejo and that the pipeline clone URL points at Forgejo. Keep GitHub-backed repository 11 active until this succeeds.

- [ ] **Step 4: Validate Forgejo Renovate discovery**

Trigger or observe the `renovate-forgejo` job and require successful extraction of `isityael/tap`. Confirm its Dependency Dashboard and any Renovate branches are on Forgejo.

- [ ] **Step 5: Remove duplicate automation ownership**

Remove `managed-by-renovate` from GitHub. Deactivate or remove Woodpecker repository 11 only after the Forgejo mapping is healthy. Confirm the GitHub mirror has no active Woodpecker webhook.

- [ ] **Step 6: Final verification**

Require:

```text
clean local working tree
local main equals Forgejo main equals GitHub main
Forgejo contains imported issues and historical pull requests
Forgejo repository has managed-by-renovate
GitHub repository does not have managed-by-renovate
Woodpecker repository forge URL is Forgejo
all local pipeline, shell, Ruby, and Homebrew checks pass
```

Do not create a fake release. Record that the next real `fast-cli` update is the production proof of dual asset publication.
