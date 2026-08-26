---
name: progen
description: Use when the user wants to create/generate/scaffold a new Spring Boot project (Maven or Gradle, REST API / Web App / Spring Boot + Angular full stack). Derives progen CLI inputs from the user's plain-English project description, asks for any missing mandatory info, ensures the progen binary is available, and runs it to generate the project. If the user asks for features progen doesn't support natively, generate the base project first, then add those features on top of the generated code.
disable-model-invocation: true
---

# progen: Spring Boot Project Generator

`progen` is an offline, single-binary Go CLI (https://github.com/sivaprasadreddy/progen) that
scaffolds a complete, production-ready Spring Boot project: build files, Java source, tests,
Docker Compose, GitHub Actions, DB migrations, security, and more.

This skill's job: turn a user's description of the app they want into a `.progen.json` config,
fill gaps by asking the user, run `progen` to generate the project, and — if the user asked for
anything progen can't do natively — layer that on afterward by editing the generated code.

## Step 1 — Ensure `progen` is available

Check for a working binary:

```bash
progen --version
```

If not found (or version looks outdated and the user wants latest), download the right asset for
the current OS/arch from the latest release:

```bash
# Example for macOS arm64 — adapt OS/ARCH from `uname -s` / `uname -m`
curl -L -o progen.tar.gz \
  "https://github.com/sivaprasadreddy/progen/releases/latest/download/progen_<os>_<arch>.tar.gz"
tar -xzf progen.tar.gz
chmod +x progen
sudo mv progen /usr/local/bin/   # or anywhere on PATH
progen --version
```

If the exact asset naming isn't obvious, fetch the releases page
(`https://github.com/sivaprasadreddy/progen/releases`) to find the correct filename for the
user's OS/architecture before downloading. If a Go toolchain is available, `go install
github.com/sivaprasadreddy/progen@latest` also works and avoids the asset-naming problem
entirely.

On macOS, downloaded binaries may trigger a Gatekeeper "cannot be opened because the developer
cannot be verified" error — tell the user to right-click → Open once in Finder to approve it (or
`xattr -d com.apple.quarantine progen` if working non-interactively is fine with them).

## Step 2 — Config schema (`.progen.json`)

`progen` takes no scaffolding info via flags — everything goes through a JSON config file
consumed as `progen -c <file>` (interactive prompts are the only other input path, and are not
used by this skill). Field names below are exactly as marshaled to JSON (Go field names,
capitalized).

| Field                   | Type / allowed values                                                                     | Default                             | Required                              |
|-------------------------|-------------------------------------------------------------------------------------------|-------------------------------------|---------------------------------------|
| `AppName`               | string (used as output directory name)                                                    | `myapp`                             | **Yes — ask if not derivable**        |
| `GroupID`               | string, e.g. `com.mycompany`                                                              | `com.mycompany`                     | **Yes — ask if not derivable**        |
| `ArtifactID`            | string, e.g. `boot-demo`                                                                  | `myapp`                             | **Yes — ask if not derivable**        |
| `AppVersion`            | string, e.g. `1.0.0`                                                                      | `1.0.0`                             | No                                    |
| `BasePackage`           | string, e.g. `com.mycompany.myapp`                                                        | derived from `GroupID`+`ArtifactID` | No                                    |
| `AppType`               | `"REST API"` \| `"Web App"` \| `"Spring Boot + Angular Full Stack"`                       | `"REST API"`                        | No (but shapes many other choices)    |
| `BuildTool`             | `"Maven"` \| `"Gradle"`                                                                   | `"Maven"`                           | No                                    |
| `PersistenceType`       | `"Spring Data JPA"` \| `"Spring JdbcClient"` \| `"jOOQ"`                                  | `"Spring Data JPA"`                 | No                                    |
| `DbType`                | `"PostgreSQL"` \| `"MySQL"` \| `"MariaDB"`                                                | `"PostgreSQL"`                      | No                                    |
| `DbMigrationTool`       | `"Flyway"` \| `"Liquibase"`                                                               | `"Flyway"`                          | No                                    |
| `SpringCloudAWSSupport` | bool                                                                                      | `false`                             | No                                    |
| `ThymeleafSupport`      | bool — set automatically to `true` when `AppType` is `"Web App"`; leave `false` otherwise | `false`                             | No (don't ask; derive from `AppType`) |
| `HTMXSupport`           | bool — only meaningful when `AppType` is `"Web App"`                                      | `false`                             | No                                    |
| `EmailSupport`          | bool                                                                                      | `false`                             | No                                    |
| `RabbitMQSupport`       | bool                                                                                      | `false`                             | No                                    |
| `RedisCachingSupport`   | bool                                                                                      | `false`                             | No                                    |
| `OpenTelemetrySupport`  | bool                                                                                      | `false`                             | No                                    |
| `K8sSupport`            | bool — generates Kubernetes manifests                                                     | `false`                             | No                                    |

Notes:
- Spring Modulith package structure, Docker Compose, Testcontainers, JUnit, Spotless, SDKMAN, GitHub Actions, Renovate, and `.editorconfig`/AI-assistant config files are always generated — there's no toggle for them.
- `"Spring Boot + Angular Full Stack"` additionally scaffolds an Angular + TailwindCSS frontend; `HTMXSupport` and `ThymeleafSupport` don't apply to it.
- Get a fresh copy of these defaults any time with `progen init`, which writes a `.progen.json` pre-filled with the defaults above into the current directory.

## Step 3 — Derive config from the user's description

Read the user's description and map it onto the fields above:

- **App/artifact identity**: look for an explicit name, company/org (→ `GroupID`), or repo-style slug (→ `ArtifactID`, `AppName`). If genuinely absent, this is mandatory — ask (see Step 4).
- **Kind of app**: "API", "backend", "microservice" → `RestApi`. "website", "server-rendered pages", "HTMX" → `WebApp` (and set `HTMXSupport` if HTMX is mentioned). "Angular", "SPA", "single page app" → `SpringBootAngularFullStack`.
- **Build tool**: "Maven"/"Gradle" mentioned explicitly → use it; otherwise default `Maven`.
- **Persistence**: "JPA"/"Hibernate" → `SpringDataJPA`; "JdbcClient"/"plain JDBC"/"no ORM" → `SpringJdbcClient`; "jOOQ" → `SpringJOOQ`.
- **Database**: "Postgres" → `PostgreSQL`; "MySQL" → `MySQL`; "MariaDB" → `MariaDB`.
- **Migrations**: "Flyway" or unspecified → `Flyway`; "Liquibase" → `Liquibase`.
- **Feature keywords** → booleans: 
  - AWS/S3/SQS/Cloud → `SpringCloudAWSSupport`; 
  - email/SMTP/notifications → `EmailSupport`; 
  - RabbitMQ/messaging/queue → `RabbitMQSupport`; 
  - caching/Redis → `RedisCachingSupport`; 
  - tracing/observability/OpenTelemetry → `OpenTelemetrySupport`;
  - Kubernetes/k8s/Helm-adjacent manifests → `K8sSupport`.
- Anything not mentioned: leave at its default rather than asking — only the identity fields in Step 4 are worth interrupting the user for.

## Step 4 — Ask about missing mandatory info

Only pause to ask when **`AppName`, `GroupID`, or `ArtifactID`** cannot be reasonably derived from
the description (progen's own prompt flow treats these three as required; everything else has a sane default). Ask concisely, e.g.:

> What should the app/artifact be called, and what's the group id (e.g. `com.acme`)?

Don't ask about `AppType`, `BuildTool`, `PersistenceType`, `DbType`, `DbMigrationTool`, or the feature booleans — apply the Step 3 mapping and fall back to defaults silently.

## Step 5 — Generate the project

Write the derived config to a `.progen.json` file, then run progen non-interactively:

```bash
cat > .progen.json <<'EOF'
{
 "AppType": "REST API",
 "AppName": "orders-service",
 "GroupID": "com.acme",
 "ArtifactID": "orders-service",
 "AppVersion": "1.0.0",
 "BasePackage": "com.acme.ordersservice",
 "BuildTool": "Maven",
 "PersistenceType": "Spring Data JPA",
 "DbType": "PostgreSQL",
 "DbMigrationTool": "Flyway",
 "SpringCloudAWSSupport": false,
 "ThymeleafSupport": false,
 "HTMXSupport": false,
 "EmailSupport": false,
 "RabbitMQSupport": false,
 "RedisCachingSupport": false,
 "OpenTelemetrySupport": false,
 "K8sSupport": false
}
EOF
progen -c .progen.json
```

This creates a new directory named after `AppName` containing the generated project (and drops a copy of the resolved config as `<AppName>/.progen.json`). 
Any invalid enum value is replaced with its default and a `WARNING:` is printed — check the command output for these.

## Step 6 — Features progen doesn't support

progen only knows the fields in Step 2's table. If the user asked for something outside that list
(e.g. GraphQL, a specific cloud provider integration beyond Spring Cloud AWS, a particular auth
provider, gRPC, a non-listed database, CI platform other than GitHub Actions):

1. Generate the base project first using the closest matching config from Steps 3–5.
2. Then add the extra feature by hand-editing the generated project — treat it as a normal Spring Boot codebase from that point on (respect its existing conventions: package layout under `BasePackage`, the chosen persistence/build tool, existing test setup, etc.).

Don't block project generation waiting on unsupported-feature design decisions — scaffold first, layer the custom feature on top second.
