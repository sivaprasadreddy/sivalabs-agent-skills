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

This is the level most of your framework-touching tests should live at. Listing `classes`
bootstraps **only** those components plus core DI — not the whole app — so it runs about as
fast as a unit test while exercising the real framework, annotations, mappings, and (via
Testcontainers) real SQL. Mock the slow/costly externals; keep everything else real.

```java
@SpringBootTest(classes = { MovieController.class, MovieService.class, ApiExceptionHandler.class })
@AutoConfigureMockMvc
@Import(TestcontainersConfig.class)               // real Postgres, not H2
class MovieControllerSlicedTest {

    @Autowired MockMvcTester mockMvc;

    // Override just the slow/paid external; the controller, service, advice and DB stay real.
    @TestConfiguration
    static class StubExternals {
        @Bean
        RecommendationClient recommendationClient() {
            RecommendationClient stub = mock(RecommendationClient.class);
            when(stub.top10(any())).thenReturn(List.of(1L, 2L, 3L));
            return stub;
        }
    }

    @Test
    void returnsTop10AndHandlesUnknownCountry() {
        assertThat(mockMvc.get().uri("/api/movies/top10?country=US")).hasStatusOk();
        assertThat(mockMvc.get().uri("/api/movies/top10?country=ZZ")).hasStatus(HttpStatus.BAD_REQUEST);
    }
}
```

Notes:

- The built-in slice annotations (`@WebMvcTest`, `@DataJpaTest`, `@JsonTest`, …) are the
  **same mechanism** — `@SpringBootTest`-style context selection with a preconfigured slice.
  Prefer them when they fit ([testing-slices-web.md](testing-slices-web.md),
  [testing-slices-persistence.md](testing-slices-persistence.md)); when they are too
  limiting, list `classes` explicitly, optionally behind a custom test-slice meta-annotation
  you reuse across the suite (e.g. `@EnableDatabaseTest` bundling the JPA + Testcontainers
  setup).
- To replace a bean, use `@MockitoBean` for a mock, or a `@TestConfiguration` `@Bean` for a
  custom stub instance. Both change the context cache key, so consolidate them in a shared
  base class to preserve context reuse (see [testing-strategy.md](testing-strategy.md)).
  Boot 4 / Spring Framework 7 improves bean-override ergonomics here.

## Full REST API over a real port (end-to-end)

For a closed-box test that drives the app only through HTTP over a real port, use
`@SpringBootTest(webEnvironment = RANDOM_PORT)` with a Testcontainers database. Siva's
[spring-boot-rest-api-testing.md](spring-boot-rest-api-testing.md) has the full
`BaseIT` + `RestTestClient` pattern — keep this layer thin.

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
- Testcontainers coordinates: 1.x (3.5.x) vs 2.x (4.x).
- 4.x-only: **context pausing** (Spring Framework 7) and improved `@TestConfiguration`
  bean-override ergonomics — see [testing-strategy.md](testing-strategy.md).

---

*The smoke-test and `@SpringBootTest(classes = …)` sliced-context approach credit **Paul
Bakker** (Netflix, Java Champion), *Testing Spring Boot the Netflix Way* —
[github.com/paulbakker/testing-spring-boot-presentation](https://github.com/paulbakker/testing-spring-boot-presentation).
Integration and WireMock patterns credit **Philip Riecks**, *Testing Spring Boot
Applications Demystified* (v4.0). API details verified against the official Spring Boot 4.x
testing reference.*
