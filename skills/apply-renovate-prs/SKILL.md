---
name: apply-renovate-prs
description: >
  Apply the changes from all open Renovate bot pull requests of a GitHub
  repository into the local working tree. Use this skill when asked to apply,
  merge locally, consolidate, batch, or try out Renovate/dependabot-style
  dependency update PRs so the combined upgrade can be built and tested in one
  go. This skill only modifies local files; it never commits, pushes, merges,
  or closes anything on GitHub.
disable-model-invocation: true
---

# Apply Renovate PRs Locally

Collect every open pull request raised by Renovate in the target GitHub
repository and apply their changes to the local working tree, so all dependency
upgrades can be built and tested together.

## Hard constraints

- **Never** run `git commit`, `git push`, `git merge`, `git cherry-pick`,
  `git rebase`, `gh pr merge`, `gh pr close`, or `gh pr review`.
- Do not create branches, tags, or worktrees unless the user asks.
- Do not modify anything on GitHub. Read-only `gh` commands only
  (`gh pr list`, `gh pr view`, `gh pr diff`, `gh api` GET).
- Leave the result as uncommitted changes in the working tree and report what
  was applied, so the user decides what to do next.

## 1. Check preconditions

```bash
gh auth status
git rev-parse --show-toplevel
git status --short --branch
```

- If `gh` is missing or unauthenticated, stop and tell the user.
- If the working tree already has uncommitted changes, report them and ask
  whether to continue on top of them or let the user stash first. Do not stash
  or discard the user's work on your own.
- Record the current branch and `git rev-parse HEAD` in the final report, so
  the user can undo with `git checkout -- .` / `git stash`.
- Fetch the base branch objects so three-way applies have the pre-image blobs:

```bash
git fetch origin
```

Determine the repository: use the `origin` remote of the current directory by
default, or the `owner/repo` the user names (pass it as `-R owner/repo` to every
`gh` command).

## 2. Discover the open Renovate PRs

```bash
gh pr list --app renovate --state open --limit 100 \
  --json number,title,headRefName,isDraft,mergeable,files,labels,url
```

If that returns nothing, Renovate may be running as a user account or a
self-hosted app, so fall back to:

```bash
gh pr list --state open --limit 100 \
  --json number,title,headRefName,author,isDraft,url \
  --jq '[.[] | select((.author.login | test("renovate"; "i")) or (.headRefName | startswith("renovate/")))]'
```

Notes:

- Renovate's "Dependency Dashboard" is a GitHub *issue*, not a PR. Ignore it.
- Exclude draft PRs by default and say so; include them only if the user asks.
- If the user restricted the scope (for example "only patch updates", "only the
  Spring Boot ones"), filter accordingly and state the applied filter.

Show the list to the user before applying, then proceed.

## 3. Order the PRs

Apply in an order that minimises conflicts:

1. Patch updates, then minor, then major (major upgrades are most likely to need follow-up source changes).
2. Manifest-only PRs before lockfile-heavy PRs.
3. Grouped PRs (Renovate branches such as `renovate/all-minor-patch`) before the single-dependency PRs they may overlap with.

Read each version bump from the PR title (Renovate titles are of the form
`chore(deps): update dependency org.foo:bar to v1.2.3`) and keep a running
table of `PR number → package → old version → new version`.

## 4. Apply each PR

For every PR, take the patch and apply it with a three-way merge:

```bash
gh pr diff <number> --patch > /tmp/renovate-<number>.patch
git apply --3way --whitespace=nowarn /tmp/renovate-<number>.patch
```

Then unstage what `--3way` staged, keeping the file contents, so the review
diff stays readable:

```bash
git reset --quiet
```

Skip the `git reset` if the user chose to continue on top of pre-existing
*staged* changes — it would unstage those too. In that case, note in the report
that the applied changes are staged.

Handle the outcomes:

- **Clean apply:** record it as applied and continue.
- **Conflict markers** (`git apply --3way` writes `<<<<<<<` into the file):
  resolve them by hand. For dependency files the resolution is almost always
  "keep both bumps" — take the higher version for each distinct dependency, and
  never leave a marker behind. Verify with
  `git grep -n '^<<<<<<<\|^>>>>>>>'`.
- **Patch fails to apply at all** (`error: patch does not apply`): do not force
  it. Instead read the PR diff (`gh pr diff <number>`) and make the equivalent
  edit directly in the manifest — change the version coordinate to the target
  version from the PR title. This is the reliable path for generated lockfiles
  and for PRs whose base is stale.
- **Lockfiles** (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`,
  `gradle.lockfile`, `uv.lock`, `poetry.lock`, `go.sum`, …): applied lockfile
  hunks from several PRs are frequently inconsistent. Prefer applying only the
  manifest changes and regenerating each lockfile once, in step 6.

Also apply Renovate PRs that touch non-code manifests — `Dockerfile`,
`docker-compose.yml`, `.github/workflows/*.yml`, `.tool-versions`,
`.sdkmanrc`, `renovate.json` — the same way.

After applying a wrapper or Docker image PR, work through the matching entry in
step 5 before moving on.

## 5. Special cases

Renovate only updates the files its managers know about. Some repositories
duplicate the same version elsewhere, so after applying a PR check for these
companion edits and make them by hand.

### Maven / Gradle wrapper PRs — also update `.sdkmanrc`

Renovate updates `.mvn/wrapper/maven-wrapper.properties` or
`gradle/wrapper/gradle-wrapper.properties`, but it does **not** update
`.sdkmanrc`, so the SDKMAN-pinned build tool stays behind.

```bash
grep -n distributionUrl .mvn/wrapper/maven-wrapper.properties \
  gradle/wrapper/gradle-wrapper.properties 2>/dev/null
cat .sdkmanrc 2>/dev/null
```

- Read the new version from `distributionUrl`
  (`apache-maven-3.9.11-bin.zip` → `3.9.11`, `gradle-9.1.0-bin.zip` → `9.1.0`)
  and set the matching `maven=` / `gradle=` line in `.sdkmanrc` to it.
- Change only the candidate the PR bumped. Leave `java=` alone unless a PR
  actually changed the project's Java version.
- Keep the SDKMAN version identifier format (e.g. `java=25-tem`, not a bare
  `25`). If unsure the exact version is published, check `sdk list maven` /
  `sdk list gradle`; if it is not available yet, leave `.sdkmanrc` untouched
  and report it.
- Wrapper PRs also carry binary hunks (`gradle-wrapper.jar`). `gh pr diff
  --patch` includes those, but if `git apply` rejects the binary hunk, take the
  file from the PR head instead:

```bash
git fetch origin pull/<number>/head
git checkout FETCH_HEAD -- gradle/wrapper/gradle-wrapper.jar
git reset --quiet
```

If the repository has no `.sdkmanrc`, do not create one.

### Docker image version PRs — also update `TestcontainersConfig`

Renovate bumps image tags in `Dockerfile`, `compose.yaml`/`docker-compose.yml`
and Kubernetes manifests, but image tags hardcoded in Java/Kotlin test
configuration are invisible to it. Update the shared Testcontainers
configuration class to the same tags.

```bash
git grep -ln "TestcontainersConfig" -- '*.java' '*.kt'
# root module and, for multi-module builds, every nested module
git grep -nE '"[a-z0-9][a-z0-9._/-]*:[a-zA-Z0-9][a-zA-Z0-9._-]*"' -- \
  'src/test/**/*.java' 'src/test/**/*.kt' \
  '**/src/test/**/*.java' '**/src/test/**/*.kt'
```

Typical declarations to update:

```java
static GenericContainer<?> mailhog = new GenericContainer<>("mailhog/mailhog:v1.0.1");
PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18-alpine");
GenericContainer<?> redis = new GenericContainer<>(DockerImageName.parse("redis:7-alpine"));
```

Rules:

- Match on the image name, not the tag: only update a literal whose repository
  part is the image the PR bumped.
- Preserve the tag flavour. If the class pins `postgres:18-alpine` and the PR
  moves compose to `postgres:19`, write `postgres:19-alpine` — do not drop the
  `-alpine`/`-jammy`/`-slim` suffix or invent one the registry lacks.
- Change only the version literal. Keep surrounding calls such as
  `DockerImageName.parse(...).asCompatibleSubstituteFor(...)`,
  `withExposedPorts(...)`, and `withDatabaseName(...)` exactly as they are.
- If the tag comes from a constant, an enum, `libs.versions.toml`, a
  `DockerImages`-style holder, or a test property, update it at that single
  source instead of at each usage.
- Check the other places test images hide: abstract base test classes,
  `*IT`/`*Tests` classes with their own `GenericContainer`,
  `src/test/resources/**` compose files, `application-test.properties`, and
  `testcontainers.properties`.
- Never bump an image in test configuration that no Renovate PR bumped.

These edits are only validated by running the tests, so make sure step 7 runs
the integration tests, not just compilation.

If the repository would benefit from Renovate tracking these files directly,
mention a `customManagers` regex manager as a follow-up suggestion in the
report — do not edit `renovate.json` unless the user asks.

## 6. Regenerate derived files once

After all PRs are applied, regenerate lockfiles/derived files a single time
using the project's own tooling. Pick the commands that match the repository:

| Ecosystem | Command                                                                 |
|-----------|-------------------------------------------------------------------------|
| Maven     | `./mvnw -q -DskipTests verify` (no lockfile; this validates resolution) |
| Gradle    | `./gradlew dependencies --write-locks` (only if lockfiles are used)     |
| npm       | `npm install --package-lock-only`                                       |
| pnpm      | `pnpm install --lockfile-only`                                          |
| yarn      | `yarn install --mode update-lockfile`                                   |
| uv        | `uv lock`                                                               |
| Poetry    | `poetry lock --no-update`                                               |
| Go        | `go mod tidy`                                                           |

Use the wrapper scripts (`./mvnw`, `./gradlew`) when present. If a command
needs network access that is unavailable, say so instead of hand-editing a
lockfile.

## 7. Verify the combined upgrade

Run the project's build and tests, preferring an existing task runner
(`Taskfile.yml`, `Makefile`, `package.json` scripts):

```bash
./mvnw verify        # or ./gradlew build, npm test, task test, ...
```

If the build breaks:

- Identify which upgrade caused it (a major bump is the usual suspect).
- Read that PR's release notes section — `gh pr view <number>` renders the body
  Renovate writes, including breaking changes.
- Make the minimal source changes needed for the new API, or, if the fix is
  large or ambiguous, revert just that one PR's files
  (`git checkout -- <paths>` for files only that PR touched) and report it as
  skipped with the reason.

Never make a test pass by weakening or deleting an assertion.

## 8. Report

Finish with a summary that contains:

- The repository, base branch, and starting commit SHA.
- A table of every Renovate PR considered: number, title, and outcome
  (`applied`, `applied with manual resolution`, `applied manually`, `skipped`).
- For skipped PRs, the concrete reason.
- The companion edits from step 5 (`.sdkmanrc`, `TestcontainersConfig`, other
  hardcoded image tags), and any that were needed but could not be made.
- The regeneration and verification commands run, and their real results —
  report failures with the relevant output rather than glossing over them.
- The list of changed files (`git status --short`).
- A reminder that nothing was committed or pushed, plus how to review and undo:

```bash
git diff                 # review everything applied
git checkout -- .        # discard all applied changes
```
