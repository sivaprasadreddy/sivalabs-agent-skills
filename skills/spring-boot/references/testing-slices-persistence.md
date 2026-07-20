# Persistence Slice Testing (JPA, JDBC, Spring Data JDBC, jOOQ)

Test the persistence layer with a slice — not the full context — and back it with a
**real** database via Testcontainers, not in-memory H2.

## The H2 false-confidence trap

Every persistence slice (`@DataJpaTest`, `@JdbcTest`, `@DataJdbcTest`, `@JooqTest`)
auto-configures an **embedded** DataSource (H2) by default. Derived queries pass on H2,
but anything database-specific silently diverges: a Postgres native query using
`to_tsvector` / `plainto_tsquery` / `ON CONFLICT` / array or JSON columns / sequences
fails against production even though the H2 test is green (`Function "TO_TSVECTOR" not
found`). Test against the database you deploy on.

**The rule for all four slices:** add
`@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)` so the
DataSource is *not* swapped for H2, and supply a Testcontainers database via
`@ServiceConnection`. See [testcontainers-wiring.md](testcontainers-wiring.md).

Prefer importing a shared container config (Siva's `TestcontainersConfig`, see
[spring-boot-rest-api-testing.md](spring-boot-rest-api-testing.md)) so one container is
reused across the whole suite and the context stays cacheable — see
[testing-strategy.md](testing-strategy.md).

## @DataJpaTest — JPA repositories

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(TestcontainersConfig.class)   // supplies the @ServiceConnection Postgres container
class BookRepositoryTest {

    @Autowired BookRepository bookRepository;

    @Test
    void runsPostgresNativeFullTextSearch() {
        bookRepository.saveAll(List.of(
                new Book("978-1", "The Lord of the Rings", "Tolkien"),
                new Book("978-2", "Fellowship of the Ring", "Tolkien")));

        var results = bookRepository.searchByTitleWithRanking("rings");

        assertThat(results).extracting(Book::title)
                .containsExactly("The Lord of the Rings", "Fellowship of the Ring");
    }
}
```

Slices are `@Transactional` and roll back after each test; a `TestEntityManager` is
available for setup, or use `@Sql("/test-data.sql")`.

**What to actually test with `@DataJpaTest`:** custom `@Query` (JPQL and native),
database-specific features, complex derived queries with edge cases, custom repository
implementations, and N+1/indexing behaviour. **Don't** test simple derived queries
(`findById`, `findByTitle`), basic CRUD, or framework behaviour — those are Spring Data's
responsibility, not yours.

## @JdbcTest — JdbcTemplate and JdbcClient

`@JdbcTest` auto-configures a DataSource plus both `JdbcTemplate` and `JdbcClient` (the
fluent client, Spring 6.1+ / Boot 3.2+, present in both 3.5.x and 4.x). Same
`replace = NONE` + Testcontainers rule.

```java
@JdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(TestcontainersConfig.class)
class BookJdbcTest {

    @Autowired JdbcClient jdbcClient;

    @Test
    void insertsAndCounts() {
        jdbcClient.sql("insert into books(isbn, title) values (?, ?)")
                  .params("978-1", "Clean Code").update();

        long count = jdbcClient.sql("select count(*) from books")
                               .query(Long.class).single();

        assertThat(count).isEqualTo(1);
    }
}
```

## @DataJdbcTest — Spring Data JDBC

For Spring Data JDBC repositories (aggregates, no JPA). Same rule.

```java
@DataJdbcTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(TestcontainersConfig.class)
class OrderRepositoryTest {

    @Autowired OrderRepository orderRepository;

    @Test
    void persistsAggregate() {
        var saved = orderRepository.save(new Order("SKU-1", 2));
        assertThat(orderRepository.findById(saved.id())).isPresent();
    }
}
```

## @JooqTest — jOOQ DSLContext

`@JooqTest` auto-configures a `DSLContext`. Same rule — jOOQ against H2 masks
dialect-specific SQL.

```java
@JooqTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(TestcontainersConfig.class)
class BookJooqTest {

    @Autowired DSLContext dsl;

    @Test
    void queriesWithDslContext() {
        int rows = dsl.insertInto(BOOKS)
                      .columns(BOOKS.ISBN, BOOKS.TITLE)
                      .values("978-1", "Clean Code")
                      .execute();
        assertThat(rows).isEqualTo(1);
    }
}
```

## 3.5.x vs 4.x

- Slice annotations, `@AutoConfigureTestDatabase`, `@ServiceConnection`, `JdbcClient`, and
  `TestEntityManager` are identical across both lines.
- **Testcontainers coordinates differ**: 1.x on 3.5.x vs 2.x on 4.x — see
  [testcontainers-wiring.md](testcontainers-wiring.md).
- **jOOQ**: the managed jOOQ major version differs between the Boot 3.5.x and 4.x BOMs;
  check `spring-boot-dependencies` for your version rather than pinning it yourself.

---

*Persistence-testing patterns credit **Philip Riecks**, *Testing Spring Boot Applications
Demystified* (v4.0), and Testcontainers patterns credit **Siva Prasad Reddy Katamreddy**
([testcontainers-samples](https://github.com/sivaprasadreddy/testcontainers-samples),
[sivalabs.in/tags/testcontainers](https://www.sivalabs.in/tags/testcontainers/)). Slice
behaviour verified against the official Spring Boot 4.x testing reference.*
