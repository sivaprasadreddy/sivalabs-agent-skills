# Testing Strategy: Choosing the Level & Keeping the Suite Fast

Read this to decide *which kind* of test to write, and why a large Spring Boot suite stays
fast. The individual how-tos live in the leaf references linked below.

## Match the test to what you are testing

The pyramid: many fast **unit** tests at the base, fewer **slice** tests in the middle, a
thin layer of **integration/e2e** tests on top.

| You are testing… | Level | Reference |
|---|---|---|
| Business/domain logic, no framework | Unit (no context) | [testing-unit-mocking.md](testing-unit-mocking.md) |
| Repository / JDBC / jOOQ queries | Persistence slice + Testcontainers | [testing-slices-persistence.md](testing-slices-persistence.md) |
| Controller, JSON, or a REST client | Web slice | [testing-slices-web.md](testing-slices-web.md) |
| The assembled system / external HTTP | Integration `@SpringBootTest` | [testing-integration.md](testing-integration.md) |
| Full REST API over a real port | End-to-end | [spring-boot-rest-api-testing.md](spring-boot-rest-api-testing.md) |

The common failure is the **wrong altitude** — reaching for `@SpringBootTest` to test
pure logic. Full context startup is ~5–15s (medium app) to 30+s (large); a slice is ~1–5s;
a unit test is milliseconds. Push each test as far down the pyramid as it will go.

## Context caching: why a big integration suite can still be fast

Spring reuses a loaded `ApplicationContext` across test classes. The first integration
test pays the startup cost; every later test with an **identical configuration** reuses the
cached context for free. Getting this right is the difference between a suite that takes
minutes and one that takes tens of minutes — one team cut 150 integration tests from
**26 minutes to 12** purely by improving cache reuse.

The cache key is the **`MergedContextConfiguration`** — Spring reuses a context only when
all of these match:

- configuration classes (`@SpringBootTest` classes / `@Import`s)
- active profiles (`@ActiveProfiles`)
- properties (`@TestPropertySource` and inline `properties = …`)
- **mock beans (`@MockitoBean` / `@MockitoSpyBean`)**
- test property sources, context initializers, context customizers

If any differ, Spring builds a **new** context (another 5–15s). So the anti-patterns are:

- **Scattered `@MockitoBean` declarations** across test classes — each unique set is a new
  context. Consolidate common mocks into an `abstract BaseIntegrationTest`.
- **Scattered property overrides** (`@TestPropertySource`/inline per class) — put shared
  test config in `application-test.properties` and use `@ActiveProfiles("test")`
  consistently.
- **`@DirtiesContext`** — it *discards* the cached context; 10 uses ≈ 50–150s wasted. Fix
  the isolation/cleanup root cause instead of reaching for it.

**Do:** one `BaseIntegrationTest` with shared `@ActiveProfiles("test")`, consolidated
`@MockitoBean`s, and shared `application-test.properties`. **Monitor** cache hits/misses
with `<logger name="org.springframework.test.context.cache" level="DEBUG"/>` in
`logback-test.xml`.

## Keep real infrastructure affordable: one container for the suite

Real-infrastructure slices (Testcontainers, see
[testcontainers-wiring.md](testcontainers-wiring.md)) are only cheap if the container is
reused. Start **one** container for the whole suite — a `static` container, or (preferred)
a shared `@ServiceConnection` bean in an imported config — rather than one per class. This
is what makes "always use a real database" practical at scale, and it composes with
context caching above.

## Mocking is a boundary tool, not a default

Mock at architectural boundaries (external services, clock, randomness); use real value
objects and pure logic. Over-mocking couples tests to internals and makes refactoring
scary rather than safe — assert *what* the code produces, not *how*. Details and examples:
[testing-unit-mocking.md](testing-unit-mocking.md).

## 3.5.x vs 4.x

- Context caching and its cache key work the same on both lines.
- **4.x-only: context pausing** (Spring Framework 7). Cached contexts freeze `@Scheduled`
  tasks, message listeners, and background threads *between* tests, then resume instantly —
  making caching reliable without `@DirtiesContext` workarounds.
- Cache-key mock beans are `@MockitoBean`/`@MockitoSpyBean` on both lines (`@MockBean` is
  deprecated on 3.5.x and removed on 4.x).

---

*Strategy, the context-caching cost model, and the pyramid framing credit **Philip Riecks**,
*Testing Spring Boot Applications Demystified* (v4.0).*
