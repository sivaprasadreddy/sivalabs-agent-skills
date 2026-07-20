# Testing Strategy: Layered Tests & Keeping the Suite Fast

Read this to decide *which levels* of test to write, and why a large Spring Boot suite
stays fast. The individual how-tos live in the leaf references linked below.

## The levels are complementary, not either/or

Slice tests and end-to-end tests are **not** a choice — you write both, because each
catches bugs the others structurally cannot:

- A **pure unit test** (Mockito, no framework) can have ~100% coverage and still pass
  while the app is broken: it ignores the persistence mapping, the request mapping, the
  serialization, the security config, and every annotation. A missing `@Controller` (or a
  schema/mapping mismatch) makes the endpoint return nothing in production — the unit test
  never notices.
- A **whole-application smoke test** catches wiring/startup failures (a bad bean
  definition, a mapping that doesn't resolve) but, as a black box, tells you little about
  *where* a behavioural bug is and is slow to run.
- A **sliced Spring test** boots the real framework around the components under test, so it
  catches annotation/mapping/SQL bugs a unit test misses — while staying fast.

So layer them. The mistake is assuming green unit tests mean you can skip the tests that
boot the framework.

## The recommended distribution (Paul Bakker / Netflix)

Roughly:

- **~95% — sliced Spring tests.** `@SpringBootTest(classes = { … })` bootstraps *only* the
  components you list (plus core DI), not the whole app — as fast as a unit test, but with
  the real framework, annotations, and (via Testcontainers) real SQL. Mock the slow/costly
  externals with a `@TestConfiguration` bean override or `@MockitoBean`; keep the rest
  real. The built-in slice annotations (`@WebMvcTest`, `@DataJpaTest`, `@JsonTest`, …) are
  the *same mechanism* with a preconfigured slice — convenient, but sometimes limiting, in
  which case fall back to an explicit `classes = { … }` list (optionally with a custom
  test-slice meta-annotation). See [testing-integration.md](testing-integration.md),
  [testing-slices-web.md](testing-slices-web.md),
  [testing-slices-persistence.md](testing-slices-persistence.md).
- **At least one smoke test**, plus at least one **request-level** end-to-end test.
  An (almost empty) `@SpringBootTest` proves the whole context starts; for a web/REST
  service, one request driven through the full stack proves the wiring actually serves a
  response. See [testing-integration.md](testing-integration.md) and
  [spring-boot-rest-api-testing.md](spring-boot-rest-api-testing.md).
- **Some unit tests** for complex framework-free business logic — fine, just rarely
  sufficient on their own. See [testing-unit-mocking.md](testing-unit-mocking.md).

### Which level(s) for what

| You are testing… | Reach for | Reference |
|---|---|---|
| Complex framework-free business logic | Unit (no context) | [testing-unit-mocking.md](testing-unit-mocking.md) |
| Repository / JDBC / jOOQ queries | Persistence slice + Testcontainers | [testing-slices-persistence.md](testing-slices-persistence.md) |
| Controller, JSON, or a REST client | Web slice | [testing-slices-web.md](testing-slices-web.md) |
| A handful of components working together | Sliced `@SpringBootTest(classes = …)` | [testing-integration.md](testing-integration.md) |
| The whole app starts / one real request end-to-end | Smoke + request-level e2e | [testing-integration.md](testing-integration.md) |
| Full REST API over a real port | End-to-end | [spring-boot-rest-api-testing.md](spring-boot-rest-api-testing.md) |

## Why the sliced test is the workhorse: context cost

Full-context `@SpringBootTest` startup is the expensive part — ~5–15s for a medium app,
30s to several minutes for a large one (data init, cache warming, IPC). That is why the
*sliced* Spring test (small context) is the default and full-context tests are kept to the
smoke/e2e handful — not because slices and e2e are alternatives, but because the full
context is what's slow.

## Context caching: keeping the boot cost paid once

Spring reuses a loaded `ApplicationContext` across test classes with an identical
configuration; the first test pays startup, later ones reuse it for free. Getting this
right is the difference between minutes and tens of minutes — one team cut 150 integration
tests from **26 to 12 minutes** purely by improving reuse.

The cache key is the **`MergedContextConfiguration`** — Spring reuses a context only when
all of these match: configuration classes / `classes`, active profiles (`@ActiveProfiles`),
properties (`@TestPropertySource` and inline `properties`), **mock beans (`@MockitoBean` /
`@MockitoSpyBean`)**, and the test's initializers/customizers. If any differ, Spring builds
a new context (another full startup). Both Riecks and Bakker call out the same trap:
**adding a `@MockitoBean` (or scattered property overrides) forks the cache** and forces a
re-initialization. So:

- Consolidate common mocks into an `abstract BaseIntegrationTest`; don't sprinkle
  `@MockitoBean` per class.
- Put shared config in `application-test.properties` + `@ActiveProfiles("test")`.
- Avoid `@DirtiesContext` — it discards the cached context (10 uses ≈ 50–150s wasted); fix
  the isolation root cause instead.
- Monitor with `<logger name="org.springframework.test.context.cache" level="DEBUG"/>`.

## Keep real infrastructure affordable: one container per suite

Real-infra tests (Testcontainers, see [testcontainers-wiring.md](testcontainers-wiring.md))
are only cheap if the container is reused: start **one** container for the whole suite (a
`static` container or a shared `@ServiceConnection` bean), not one per class. On CI where
Docker isn't available on the host (e.g. Jenkins), Testcontainers Cloud runs the container
remotely with transparent port-forwarding. This composes with context caching to make
"always use a real database" practical at scale.

## Mocking is a boundary tool

Mock at architectural boundaries (external services, clock, randomness) — Bakker's example
mocks the slow, paid OpenAI call while keeping the database real; use real value objects and
pure logic elsewhere. Over-mocking couples tests to internals; assert *what* the code
produces, not *how*. See [testing-unit-mocking.md](testing-unit-mocking.md).

## 3.5.x vs 4.x

- Context caching and its cache key work the same on both lines.
- **4.x-only: context pausing** (Spring Framework 7) freezes `@Scheduled` tasks and
  listeners in cached contexts between tests, then resumes instantly — reducing the need for
  `@DirtiesContext`. 4.x also improves bean-override ergonomics for `@TestConfiguration`.
- Cache-key mock beans are `@MockitoBean`/`@MockitoSpyBean` on both lines (`@MockBean`
  deprecated on 3.5.x, removed on 4.x).

---

*The layered model and the ~95%-sliced-tests distribution credit **Paul Bakker** (Netflix,
Java Champion), *Testing Spring Boot the Netflix Way* —
[github.com/paulbakker/testing-spring-boot-presentation](https://github.com/paulbakker/testing-spring-boot-presentation).
The context-caching cost model and pyramid framing credit **Philip Riecks**, *Testing
Spring Boot Applications Demystified* (v4.0).*
