# Integration, Sliced-Context & End-to-End Testing

`@SpringBootTest` spans a range — from a **full-context smoke test** (boots everything) to a
fast **sliced-context test** (`classes = { … }`, boots only what you list). These
**complement** the single-annotation slices and unit tests; you write all of them (see
[testing-strategy.md](testing-strategy.md) for the layered model). This reference covers the
whole-context and multi-component tests.

## Smoke tests — does the app actually start and serve?

The cheapest high-value test: prove the whole context wires up. A pure unit test can be
green while the app is broken (missing/mismatched mapping, bad bean); a smoke test catches
that class of failure. Write one per application.

```java
@SpringBootTest
class ApplicationSmokeTest {

    @Test
    void contextLoads() { }   // fails on any DI / config / mapping wiring error
}
```

Startup succeeding is not the same as the app *working*: an endpoint whose handler
annotation is missing may still start fine and simply return nothing. So for a web/REST
service, add **at least one request-level** smoke test that drives a real request through
the full stack:

```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@Import(TestcontainersConfig.class)
class TopLevelRequestSmokeTest {

    @Autowired RestTestClient restTestClient;   // 4.x; on 3.5.x use WebTestClient/TestRestTemplate

    @Test
    void topEndpointServesAResponse() {
        restTestClient.get().uri("/api/movies/top10?country=US")
                .exchange()
                .expectStatus().isOk();
    }
}
```

## Sliced-context tests: `@SpringBootTest(classes = { … })` — the workhorse

This is the level most framework-touching tests should live at. It has **two building
blocks** working together:

1. `@SpringBootTest(classes = { … })` registers exactly the components under test (plus a
   `@TestConfiguration` that stubs slow/costly externals) — not the whole app.
2. A **test-slice annotation** pulls in the auto-configuration the layer needs. Listing
   `classes` alone gives you the beans but *not* the framework wiring (JPA repositories, the
   web/GraphQL layer, …); the slice supplies that. Use a built-in slice (`@WebMvcTest`,
   `@DataJpaTest`, …) — which is exactly `@SpringBootTest(classes)` + a preselected slice
   under the hood — or, when you need to combine layers, a **custom meta-annotation** you
   write once and reuse.

**Mock the external, keep the rest real** — put the stub in a `@TestConfiguration` and list
it in `classes`:

```java
@TestConfiguration
class StubExternals {
    @Bean
    RecommendationClient recommendationClient() {         // the slow/paid dependency
        var mock = mock(RecommendationClient.class);
        when(mock.top10("US")).thenReturn(List.of(1L, 2L, 3L));
        return mock;
    }
}
```

**Variant A — mock the repository (fastest; no database).** Unit-test speed, but real
service wiring:

```java
@SpringBootTest(classes = { MovieService.class, StubExternals.class })
class MovieServiceSlicedTest {

    @Autowired MovieService movieService;
    @MockitoBean MovieRepository movieRepository;   // 3.4+/4.x; @MockBean on older 3.x

    @Test
    void ranksTop10() {
        when(movieRepository.findAllById(any())).thenReturn(List.of(/* ... */));
        assertThat(movieService.top10("US")).hasSize(3);
    }
}
```

**Variant B — real database via a custom Testcontainers slice.** Drop the repository mock,
list the real repository, and add a reusable slice that wires JPA + a real Postgres. This
pays a container start (so it is *not* unit-test fast) but exercises real SQL:

```java
@SpringBootTest(classes = { MovieService.class, MovieRepository.class, StubExternals.class })
@EnableDatabaseTest
class MovieServiceTestcontainersTest {

    @Autowired MovieService movieService;

    @Test
    void ranksTop10FromRealDb() {
        assertThat(movieService.top10("US"))
                .extracting(Movie::title).contains("Stranger Things");
    }
}
```

The `@EnableDatabaseTest` meta-annotation — written **once**, reused across the suite —
bundles the JPA + Testcontainers wiring (this is Paul Bakker's pattern, adapted):

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@EnableJpaRepositories(basePackages = "com.example.movies.repository")
@EntityScan("com.example.movies.repository")
@AutoConfigureDataJpa
@AutoConfigureTestEntityManager
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)   // keep Postgres, not H2
@Import(PostgresTestContainerConfig.class)
public @interface EnableDatabaseTest {}
```

```java
@TestConfiguration(proxyBeanMethods = false)
public class PostgresTestContainerConfig {

    @Bean
    @ServiceConnection                                   // wires spring.datasource.* — no manual props
    PostgreSQLContainer<?> postgres() {
        return new PostgreSQLContainer<>("postgres:18-alpine")   // pin the tag, never untagged/latest
                .withInitScript("shows.sql");
    }
}
```

Notes:

- Prefer the built-in slices (`@WebMvcTest`, `@DataJpaTest`, `@JsonTest`) when a single
  layer is enough — see [testing-slices-web.md](testing-slices-web.md),
  [testing-slices-persistence.md](testing-slices-persistence.md). Reach for
  `@SpringBootTest(classes = …)` + a slice when you want a few real layers wired together.
- Assert through the layer's own entry point — a controller via `@WebMvcTest`+`MockMvcTester`,
  a service directly, a GraphQL executor, etc. You do **not** need `@AutoConfigureMockMvc` at
  this level unless you are deliberately exercising the HTTP layer (that belongs to the
  request-level smoke test above or the e2e test below).
- `@MockitoBean` and each distinct `@TestConfiguration` change the context cache key;
  consolidate shared ones in a base class to preserve context reuse (see
  [testing-strategy.md](testing-strategy.md)). Boot 4 / Spring Framework 7 improves
  bean-override ergonomics here.
- If the suite already imports the shared `TestcontainersConfig` (from
  [spring-boot-rest-api-testing.md](spring-boot-rest-api-testing.md)) for the e2e layer,
  reuse it here instead of `PostgresTestContainerConfig` — two different container
  configs in the same suite means two Postgres containers and two context-cache
  families.

## Full REST API over a real port (end-to-end)

For a closed-box test that drives the app only through HTTP over a real port, use
`@SpringBootTest(webEnvironment = RANDOM_PORT)` with a Testcontainers database. Siva's
[spring-boot-rest-api-testing.md](spring-boot-rest-api-testing.md) has the full
`BaseIT` + `RestTestClient` pattern — keep this layer thin.

**Boot 4 — one client across levels.** `RestTestClient` (Spring Framework 7) unifies
MockMvc and WebTestClient behind a single fluent API, with a bind mode for each test level:
`bindToController(...)` (no context, mock collaborators by hand), `bindTo(MockMvc)` (over an
MVC slice), `bindToApplicationContext(...)` (real context), and `bindToServer()` (real
port). So the same client can span the sliced-to-e2e range rather than switching tools per
level — a natural fit for the layered model in [testing-strategy.md](testing-strategy.md).
On 3.5.x there is no `RestTestClient`; use `MockMvcTester`/`WebTestClient`/`TestRestTemplate`.
*(Credit: [Dan Vega — Spring Framework 7 RestTestClient](https://www.danvega.dev/blog/spring-framework-7-rest-test-client); bind-mode names verified against the Spring Framework 7 `RestTestClient` source.)*

## External HTTP: built-in first, WireMock when you need a port

Full and sliced tests still call whatever external services the code depends on, so stub
them:

1. **Default — `@RestClientTest` + `MockRestServiceServer`** for `RestClient`/`RestTemplate`
   clients (in-process, no port). See [testing-slices-web.md](testing-slices-web.md). For a
   costly/slow external inside a larger `@SpringBootTest`, a `@TestConfiguration`/
   `@MockitoBean` stub of the client bean (as above) is usually enough.
2. **Escalate to WireMock** only when you need a real HTTP server on a port: the client is
   `WebClient`/an HTTP-interface/a third-party SDK; you need real timeouts/TLS/retries;
   fault/latency injection; or a stub shared across the full context.
   **Rule of thumb: built-in for the slice, WireMock for the port.**

WireMock 3.x is `org.wiremock:wiremock-standalone` (test scope). Its port is assigned at
startup, so its base URL is a textbook `@DynamicPropertySource` value (see
[testcontainers-wiring.md](testcontainers-wiring.md)):

```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@Import(TestcontainersConfig.class)
class CheckoutIntegrationTest {

    @RegisterExtension
    static WireMockExtension wm = WireMockExtension.newInstance()
            .options(wireMockConfig().dynamicPort())
            .build();

    @DynamicPropertySource
    static void paymentServiceProps(DynamicPropertyRegistry registry) {
        registry.add("app.payments.base-url", wm::baseUrl);  // known only after wm starts
    }

    @Autowired RestTestClient restTestClient;

    @Test
    void checkoutChargesViaPaymentService() {
        wm.stubFor(post("/charge").willReturn(okJson("{\"status\":\"PAID\"}")));

        restTestClient.post().uri("/api/checkout").exchange().expectStatus().isOk();
    }
}
```

## 3.5.x vs 4.x

- `@SpringBootTest` (incl. `classes = …`), `RANDOM_PORT`, `@ServiceConnection`, and WireMock
  work the same on both lines.
- **REST test client**: on 4.x prefer `RestTestClient` (`@AutoConfigureRestTestClient`) or
  `TestRestTemplate` (`@AutoConfigureTestRestTemplate` — required on 4.x); both live in the
  new `spring-boot-resttestclient` module. On 3.5.x use `WebTestClient`/`TestRestTemplate`.
- Testcontainers coordinates: 1.x (3.5.x) vs 2.x (4.x) — see
  [testcontainers-wiring.md](testcontainers-wiring.md).
- **Test-autoconfigure annotations moved packages in Boot 4** (modular restructuring), so
  the imports in a custom slice like `@EnableDatabaseTest` differ by version — let your IDE
  resolve them. For example: `AutoConfigureDataJpa` is `org.springframework.boot.data.jpa.test.autoconfigure`
  on 4.x vs `org.springframework.boot.test.autoconfigure.orm.jpa` on 3.5.x; `@EntityScan` is
  `org.springframework.boot.persistence.autoconfigure` on 4.x vs `org.springframework.boot.autoconfigure.domain`
  on 3.5.x. (`@EnableJpaRepositories` stays in Spring Data's `org.springframework.data.jpa.repository.config`.)
- 4.x-only: **context pausing** (Spring Framework 7) and improved `@TestConfiguration`
  bean-override ergonomics — see [testing-strategy.md](testing-strategy.md).

---

*The smoke-test and `@SpringBootTest(classes = …)` sliced-context approach credit **Paul
Bakker** (Netflix, Java Champion), *Testing Spring Boot the Netflix Way* —
[github.com/paulbakker/testing-spring-boot-presentation](https://github.com/paulbakker/testing-spring-boot-presentation).
Integration and WireMock patterns credit **Philip Riecks**, *Testing Spring Boot
Applications Demystified* (v4.0). API details verified against the official Spring Boot 4.x
testing reference.*
