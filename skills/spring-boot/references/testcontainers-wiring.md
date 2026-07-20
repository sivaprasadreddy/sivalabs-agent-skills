# Testcontainers Wiring: @ServiceConnection vs Dynamic Properties

How to connect a Spring Boot test to a Testcontainers container **correctly**. Two
mechanisms exist, and choosing wrong is the single most common Testcontainers mistake.

- [Rule: @ServiceConnection first](#serviceconnection)
- [What goes where: the three-way rule](#dynamic-vs-static-properties)

See [testing-slices-persistence.md](testing-slices-persistence.md) and
[testing-integration.md](testing-integration.md) for where this is applied.

## @ServiceConnection {#serviceconnection}

Use `@ServiceConnection` (Spring Boot 3.1+) whenever Spring Boot ships a
`ConnectionDetailsFactory` for the container. Boot then reads the container's mapped
host/port/URL/credentials and wires the matching `*ConnectionDetails` bean **for you** —
you register **no** properties.

Containers with a built-in factory (verified against the Boot 4.x reference):

- **JDBC databases** (`JdbcConnectionDetails` for any `JdbcDatabaseContainer`: Postgres,
  MySQL, MariaDB, Oracle, MSSQL) and the **R2DBC** equivalents
- MongoDB, Redis, Cassandra, Couchbase, Elasticsearch, Neo4j
- Kafka (incl. Confluent/Redpanda), RabbitMQ, ActiveMQ, Artemis, Pulsar
- Zipkin, OpenTelemetry (OTLP logging/metrics/tracing), LDAP, Flyway, Liquibase

```java
@Container
@ServiceConnection
static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:18-alpine");
```

For a `GenericContainer` (no specific container type), give the factory a name hint:

```java
@Bean
@ServiceConnection(name = "redis")
GenericContainer<?> redis() {
    return new GenericContainer<>("redis:7-alpine").withExposedPorts(6379);
}
```

**No factory?** (e.g. MailHog, a bespoke service.) `@ServiceConnection` does nothing —
fall back to dynamic properties below. Siva's `TestcontainersConfig` in
[spring-boot-rest-api-testing.md](spring-boot-rest-api-testing.md) shows both in one file:
`@ServiceConnection` for Postgres/Redis, a `DynamicPropertyRegistrar` for MailHog's
`spring.mail.*`.

## What goes where: the three-way rule {#dynamic-vs-static-properties}

LLMs (and people) routinely put static config into `@DynamicPropertySource` and try to
pin dynamic ports into properties files. Decide with this table:

| The value is… | Put it in… | Why |
|---|---|---|
| Connection details for a container with a factory | **nowhere** — `@ServiceConnection` | auto-wired; registering it manually is redundant and can conflict |
| Known **only after the container starts** (mapped host/port/URL of a *factory-less* container) | `DynamicPropertyRegistrar` bean (preferred) or `@DynamicPropertySource` (lazy `Supplier`) | the mapped port is assigned at `start()`, not when you write the test |
| Fixed and known **when you write the test** (`spring.jpa.hibernate.ddl-auto`, feature flags, disabled scheduler, cache TTL, log levels, fixed creds) | `application-test.properties` / `@TestPropertySource` | static config; belongs in a properties file |

**Mental model:** `@DynamicPropertySource` is for values that *don't exist yet at
authoring time* — that is why the API takes a `Supplier`, not a `String`. Anything you
could type as a literal into a `.properties` file does not belong there.

```java
// Correct: a factory-less container's mapped port, resolved lazily at runtime
@DynamicPropertySource
static void mailProps(DynamicPropertyRegistry registry) {
    registry.add("spring.mail.host", mailhog::getHost);
    registry.add("spring.mail.port", mailhog::getFirstMappedPort);
}
```

### Prefer `DynamicPropertyRegistrar` (bean) over the static method

The `DynamicPropertyRegistrar` bean (Spring Boot 3.4+) is preferred over a static
`@DynamicPropertySource` method: it can depend on other beans, lives cleanly in a
`@TestConfiguration`, and orders correctly alongside `@ServiceConnection`.

```java
@Bean
DynamicPropertyRegistrar mailProperties(GenericContainer<?> mailhog) {
    return registry -> {
        registry.add("spring.mail.host", mailhog::getHost);
        registry.add("spring.mail.port", mailhog::getFirstMappedPort);
    };
}
```

### Two anti-patterns to reject

- **Static value in `@DynamicPropertySource`** (e.g. registering `ddl-auto` there) — it
  belongs in `application-test.properties`.
- **Dynamic port pinned to a static file / fixed host ports** (`withFixedExposedPorts`,
  hard-coded `5432`) — causes port clashes and flaky parallel runs; let Testcontainers
  map a random port and read it lazily.

## 3.5.x vs 4.x

Both `@ServiceConnection` (3.1+) and `DynamicPropertyRegistrar` (3.4+) exist in both
lines. The difference is Testcontainers coordinates: **1.x** on Boot 3.5.x
(`org.testcontainers:junit-jupiter`, `:postgresql`, `org.testcontainers.containers.*`)
vs **2.x** on Boot 4.x (`testcontainers-junit-jupiter`, `testcontainers-postgresql`,
`org.testcontainers.postgresql.PostgreSQLContainer`). See
[spring-boot-rest-api-testing.md](spring-boot-rest-api-testing.md) for the 2.x note.

---

*Testcontainers patterns credit **Siva Prasad Reddy Katamreddy** —
[testcontainers-samples](https://github.com/sivaprasadreddy/testcontainers-samples),
[sivalabs.in/tags/testcontainers](https://www.sivalabs.in/tags/testcontainers/) — and
**Philip Riecks**, *Testing Spring Boot Applications Demystified* (v4.0). `@ServiceConnection`
support matrix verified against the official Spring Boot 4.x testing reference.*
