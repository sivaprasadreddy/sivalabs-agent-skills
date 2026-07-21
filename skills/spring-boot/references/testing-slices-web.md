# Web & Serialization Slice Testing (@WebMvcTest, @JsonTest, @RestClientTest)

Slices for the non-persistence layers. Each loads only its layer's beans, so it is far
faster than `@SpringBootTest` — see [testing-strategy.md](testing-strategy.md).

## @WebMvcTest — controllers in isolation

Loads the web layer only (controllers, `@ControllerAdvice`, filters, converters,
`MockMvc`); `@Service`/`@Repository`/`@Component` are **not** loaded, so a collaborator the
controller needs must be a `@MockitoBean` or the context fails to start.

For the full controller-testing API (request mapping, validation, JSON assertions, view
rendering), use the existing
[spring-boot-webapp-testing-with-mockmvctester.md](spring-boot-webapp-testing-with-mockmvctester.md)
— prefer `MockMvcTester` (AssertJ-style, 3.4+). Two non-obvious gotchas to carry from here:

- **Security is not auto-applied in slices.** With recent Spring Security, `@WebMvcTest`
  does **not** pick up your custom `SecurityConfig` automatically — `@Import` it explicitly,
  or your test runs against Boot's default chain (often a surprise 401):

  ```java
  @WebMvcTest(BookController.class)
  @Import(SecurityConfig.class)
  class BookControllerTest {
      @Autowired MockMvcTester mockMvc;
      @MockitoBean BookService bookService;   // @Service not on the web slice
  }
  ```

- **Simulate authentication** with `spring-boot-starter-security-test` + `@WithMockUser`:
  `@WithMockUser(roles = "ADMIN")` on a test asserts the secured path; no annotation
  asserts 401; wrong role asserts 403.

## @JsonTest — serialization of a DTO

Loads only Jackson/JSON configuration and provides `JacksonTester` (also `GsonTester`,
`JsonbTester`, `BasicJsonTester`). Use it to pin a DTO's wire format.

```java
@JsonTest
class BookJsonTest {

    @Autowired JacksonTester<Book> json;

    @Test
    void serializesBook() throws Exception {
        assertThat(json.write(new Book("978-1", "Clean Code", "Martin")))
                .hasJsonPathStringValue("$.isbn")
                .extractingJsonPathStringValue("$.title").isEqualTo("Clean Code");
    }
}
```

## @RestClientTest — the built-in way to stub external HTTP

For code that **calls out** via `RestClient` or `RestTemplate`, `@RestClientTest`
auto-configures the client plus a `MockRestServiceServer`. This is the built-in,
in-process stub: no port, no extra dependency, no real socket. Reach for it first.

```java
@RestClientTest(WeatherClient.class)
class WeatherClientTest {

    @Autowired WeatherClient client;
    @Autowired MockRestServiceServer server;   // auto-configured

    @Test
    void fetchesForecast() {
        server.expect(requestTo("/forecast?city=Berlin"))
              .andRespond(withSuccess("{\"tempC\":21}", MediaType.APPLICATION_JSON));

        assertThat(client.forecastFor("Berlin").tempC()).isEqualTo(21);
    }
}
```

`MockRestServiceServer` only intercepts Spring's `RestClient`/`RestTemplate`. For
`WebClient`/HTTP-interface/SDK clients or when you need a real port, escalate to WireMock —
see [testing-integration.md](testing-integration.md) for the full built-in-vs-WireMock rule.

## 3.5.x vs 4.x

- `@WebMvcTest`, `@JsonTest`, `@RestClientTest`, `MockRestServiceServer`, `JacksonTester`,
  and `@WithMockUser` are identical across both lines.
- **`@JsonTest` JSON mapper**: Jackson 2 (`com.fasterxml.jackson`) on 3.5.x vs Jackson 3
  (`tools.jackson`) on 4.x — the DTO assertions are the same; only the underlying mapper
  package differs.
- The web slice test starter is `spring-boot-starter-test` on 3.5.x and
  `spring-boot-starter-webmvc-test` on 4.x.

---

*Slice-testing patterns credit **Philip Riecks**, *Testing Spring Boot Applications
Demystified* (v4.0). API details verified against the official Spring Boot 4.x testing
reference.*
