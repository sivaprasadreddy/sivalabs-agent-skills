# Integration & End-to-End Testing (@SpringBootTest, WireMock)

`@SpringBootTest` loads the whole application context — every bean, all auto-config. It is
the slowest layer (startup ~5–30s vs ~1–5s for a slice), so use it **sparingly**, for the
things that only break when the system is assembled. For everything else, use a slice
([testing-slices-web.md](testing-slices-web.md),
[testing-slices-persistence.md](testing-slices-persistence.md)) and keep the suite fast
([testing-strategy.md](testing-strategy.md)).

## When a full integration test is justified

- Critical end-to-end workflows: registration/login, payment, order fulfilment,
  data import/export
- Interactions spanning controller → service → repository → database
- External API integration (client config, retries, timeouts, response mapping)
- Security flows across the whole chain (authn/authz)

**Not** for: simple business logic (unit test), single repository queries (`@DataJpaTest`),
controller request mapping (`@WebMvcTest`), or JSON serialization (`@JsonTest`).

## Full REST API over a real port (end-to-end)

For a closed-box test that drives the app only through HTTP, use
`@SpringBootTest(webEnvironment = RANDOM_PORT)` with a Testcontainers database. This is the
top of the pyramid — keep it thin. Siva's
[spring-boot-rest-api-testing.md](spring-boot-rest-api-testing.md) covers the full
`BaseIT` + `RestTestClient` setup; use that as the canonical pattern rather than
duplicating it here. `RANDOM_PORT` picks a free port so these tests run in parallel
without clashes.

## External HTTP: built-in first, WireMock when you need a port

A full integration test will call whatever external services your code depends on — and
those calls fail (or hit the network) unless you stub them. Two tools, in order:

1. **Default — `@RestClientTest` + `MockRestServiceServer`** for `RestClient`/`RestTemplate`
   clients. In-process, no port, no dependency. See
   [testing-slices-web.md](testing-slices-web.md).

2. **Escalate to WireMock** only when the built-in stub can't do the job — because WireMock
   runs a *real* HTTP server on a port, and that is exactly what buys you the extra
   capability:
   - the client is `WebClient`, an HTTP-interface client, or a third-party SDK with its
     own HTTP stack (`MockRestServiceServer` can't intercept these)
   - you need real socket behaviour: connection timeouts, TLS, retries, streaming
   - fault/latency injection, record/replay, or a stub shared across the full
     `@SpringBootTest`

   **Rule of thumb: built-in for the slice, WireMock for the port.**

WireMock 3.x is `org.wiremock:wiremock-standalone` (test scope). Because its port is
assigned when the server starts, its base URL is a textbook
`@DynamicPropertySource` value — not something you can hard-code (see
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

        restTestClient.post().uri("/api/checkout")
                .exchange()
                .expectStatus().isOk();
    }
}
```

## 3.5.x vs 4.x

- `@SpringBootTest`, `RANDOM_PORT`, `@ServiceConnection`, and WireMock are the same across
  both lines.
- **REST test client**: on 4.x prefer `RestTestClient` (with `@AutoConfigureRestTestClient`)
  or `TestRestTemplate` (with `@AutoConfigureTestRestTemplate` — required on 4.x); both live
  in the new `spring-boot-resttestclient` module. On 3.5.x use `WebTestClient` or
  `TestRestTemplate` (no `RestTestClient`, no `@AutoConfigureTestRestTemplate` needed).
- Testcontainers coordinates: 1.x (3.5.x) vs 2.x (4.x).
- 4.x-only: **context pausing** (Spring Framework 7) freezes `@Scheduled` tasks and
  listeners in cached contexts between tests — see [testing-strategy.md](testing-strategy.md).

---

*Integration-testing patterns, including the WireMock approach, credit **Philip Riecks**,
*Testing Spring Boot Applications Demystified* (v4.0). API details verified against the
official Spring Boot 4.x testing reference.*
