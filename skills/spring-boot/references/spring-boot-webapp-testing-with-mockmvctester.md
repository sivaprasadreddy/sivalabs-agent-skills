# Spring Boot Web Application Testing with MockMvcTester

## Key principles

Follow these principles when testing Spring Boot Web MVC controllers with MockMvcTester:

- Use `MockMvcTester` for AssertJ-style fluent assertions (Spring Boot 3.4+)
- Use `@WebMvcTest` for slice tests that focus on a single controller
- Use `@SpringBootTest` with `@AutoConfigureMockMvc` for integration tests

## Setup

### Dependencies

Add the following dependency:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-webmvc-test</artifactId>
    <scope>test</scope>
</dependency>
```

### Slice Test Setup (@WebMvcTest)

For testing a single controller in isolation:

```java
@WebMvcTest(controllers = UserController.class)
class UserControllerTests {

    @Autowired
    MockMvcTester mockMvc;

    @MockitoBean
    UserService userService;

    // tests...
}
```

### Integration Test Setup (@SpringBootTest)

For full integration tests:

```java
@SpringBootTest
@AutoConfigureMockMvc
class UserControllerIT {

    @Autowired
    MockMvcTester mockMvc;

    // tests...
}
```

### Migrating from MockMvc

If gradually adopting MockMvcTester:

```java
@Autowired
MockMvc mockMvc;

MockMvcTester mockMvcTester;

@PostConstruct
void setUp() {
    mockMvcTester = MockMvcTester.create(mockMvc);
}
```

## Basic test structure

Simple single-statement assertions:

```java
@Test
void shouldRenderHomePage() {
    assertThat(mockMvcTester.get().uri("/home"))
        .hasStatusOk();
}
```

## Testing the view rendering controllers

### Assert view name and model attributes

```java
@Test
void shouldGetUserById() {
    var result = mockMvcTester.get().uri("/users/1").exchange();
    assertThat(result)
            .hasStatusOk()
            .hasViewName("user")
            .model()
            .containsKeys("user")
            .containsEntry("user", new User(1L, "Siva", "siva@gmail.com", "siva"));
}
```

### Assert URL redirects and flash attributes

```java
@Test
void shouldCreateUserSuccessfully() {
    var result = mockMvcTester.post().uri("/users")
            .contentType(MediaType.APPLICATION_FORM_URLENCODED)
            .param("name", "Test User 4")
            .param("email", "testuser4@gmail.com")
            .param("password", "testuser4")
            .exchange();
    assertThat(result)
            .hasStatus(HttpStatus.FOUND)
            .hasRedirectedUrl("/users")
            .flash().containsKey("successMessage")
            .hasEntrySatisfying("successMessage",
                    value -> assertThat(value).isEqualTo("User saved successfully"));
}
```

### Assert model validation errors

```java
@Test
void shouldGetErrorsWhenUserDataIsInvalid() {
   var result = mockMvcTester.post().uri("/users")
           .contentType(MediaType.APPLICATION_FORM_URLENCODED)
           .param("name", "") // blank -invalid
           .param("email", "testuser4gmail.com") // invalid email format
           .param("password", "pwd") // valid
           .exchange();
   assertThat(result)
           .model()
           .extractingBindingResult("user")
           .hasErrorsCount(2)
           .hasFieldErrors("name", "email");
}
```
