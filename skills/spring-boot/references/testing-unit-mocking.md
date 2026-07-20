# Unit Testing & Mocking (no Spring context)

The base of the pyramid: test business/domain logic in plain JUnit + Mockito + AssertJ
with **no Spring context**. These run in milliseconds, so most of your tests should live
here. You are testing *your* code, not the framework — Spring has its own tests.

Constructor injection is what makes a Spring bean trivially unit-testable: instantiate it
with test doubles, no container required.

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock OrderRepository orderRepository;   // collaborator at a boundary -> mock
    @Mock PaymentGateway paymentGateway;     // external service -> mock
    @InjectMocks OrderService orderService;

    @Test
    void placesOrderAndCharges() {
        var command = new PlaceOrder("SKU-1", 2);
        when(orderRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        Order order = orderService.place(command);

        assertThat(order.status()).isEqualTo(OrderStatus.PLACED);
        verify(paymentGateway).charge(order.total());
    }
}
```

## What to mock — and what not to

Mock at **architectural boundaries**: external services, the database/repository, the
clock, randomness. Use the **real** thing for value objects, domain entities, and pure
logic — mocking those just couples the test to internals.

Over-mocking is a smell. Two habits keep tests refactor-safe:

- **Assert behaviour, not implementation.** Verify *what* the code produces, not *how* it
  computed it. Testing `spy(service).verify(internalSortMethod())` locks the test to the
  implementation; asserting the returned list is sorted does not.
- **Use `verify()` sparingly** — mainly to prove a side effect happened (a charge was
  issued) or did *not* (`verifyNoInteractions(paymentGateway)` for an empty cart).

## Keep cases DRY

Collapse near-identical cases with `@ParameterizedTest` (`@ValueSource` / `@CsvSource` /
`@MethodSource`) rather than copy-pasting test methods.

## What not to unit-test at all

Getters/setters, framework wiring (`@Autowired` injection works — that's Spring's job),
and private methods via reflection (if a private method needs its own test, extract it to
a class of its own). Prefer AssertJ's fluent assertions (`extracting`, `satisfies`,
`containsExactlyInAnyOrder`) for readable expectations.

## 3.5.x vs 4.x

This layer is version-agnostic: the only difference is the JUnit version — **JUnit 5** on
3.5.x, **JUnit 6** on 4.x — which does not change any of the code above. Mockito and
AssertJ come transitively via the test starter in both lines.

> **GraalVM native image:** Mockito does not work in a native image, so `@Mock`-based tests
> (and `@MockitoBean`) can't run under `nativeTest` — see the native-image caveat in
> [testing-strategy.md](testing-strategy.md).

---

*Unit-testing and mocking guidance credit **Philip Riecks**, *Testing Spring Boot
Applications Demystified* (v4.0).*
