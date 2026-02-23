# Spring Boot REST API Testing

- [Key principles](#key-principles)
- [TestcontainersConfig](#testcontainersconfigjava)
- [BaseIT](#baseitjava)
- [Sample controller test](#sample-restcontroller-test)

## Key principles

Follow these principles when testing Spring Boot Web MVC REST APIs:

- Use `RestTestClient` to test API endpoints
- Use Testcontainers to setup test dependencies like databases, message brokers, etc
- Create a base test class for common setup and teardown
- Use `@SpringBootTest` with `webEnvironment = WebEnvironment.RANDOM_PORT` for integration testing
- Use `test` profile and create `application-test.properties` for test-specific configurations
- Use SQL scripts for database setup and teardown


## TestcontainersConfig.java

Add Testcontainers dependencies:

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-testcontainers</artifactId>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>testcontainers-junit-jupiter</artifactId>
        <scope>test</scope>
    </dependency>
    <!-- if using PostgreSQL -->
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>testcontainers-postgresql</artifactId>
        <scope>test</scope>
    </dependency>
</dependencies>
```

**IMPORTANT:** Make sure to use the Testcontainers 2.x maven dependency coordinates are used and non-deprecated classes are used.

- Use `org.testcontainers:testcontainers-junit-jupiter` instead of `org.testcontainers:junit-jupiter`
- Use `org.testcontainers:testcontainers-postgresql` instead of `org.testcontainers:postgresql`
- Use `org.testcontainers.postgresql.PostgreSQLContainer` instead of `org.testcontainers.containers.PostgreSQLContainer`


```java
package dev.sivalabs.projectname;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.springframework.test.context.DynamicPropertyRegistrar;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@TestConfiguration(proxyBeanMethods = false)
public class TestcontainersConfig {

    static GenericContainer<?> mailhog = new GenericContainer<>("mailhog/mailhog:v1.0.1").withExposedPorts(1025);

    static {
        mailhog.start();
    }

    @Bean
    @ServiceConnection
    PostgreSQLContainer postgresContainer() {
        return new PostgreSQLContainer("postgres:18-alpine");
    }

    @Bean
    @ServiceConnection(name = "redis")
    GenericContainer<?> redisContainer() {
        return new GenericContainer<>(DockerImageName.parse("redis:7-alpine")).withExposedPorts(6379);
    }

    @Bean
    DynamicPropertyRegistrar dynamicPropertyRegistrar() {
        return (registry) -> {
            registry.add("spring.mail.host", mailhog::getHost);
            registry.add("spring.mail.port", mailhog::getFirstMappedPort);
        };
    }
}
```

## BaseIT.java

```java
package dev.sivalabs.projectname;

import static org.springframework.boot.test.context.SpringBootTest.WebEnvironment.RANDOM_PORT;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.web.servlet.client.RestTestClient;
import tools.jackson.databind.json.JsonMapper;

@SpringBootTest(webEnvironment = RANDOM_PORT)
@Import(TestcontainersConfig.class)
@AutoConfigureRestTestClient
@Sql("/test-data.sql")
public abstract class BaseIT {
    public static final String ADMIN_EMAIL = "admin@gmail.com";
    public static final String ADMIN_PASSWORD = "Admin@1234";
    public static final String USER_EMAIL = "siva@gmail.com";
    public static final String USER_PASSWORD = "Siva@1234";
    
    @Autowired
    protected RestTestClient restTestClient;

    @Autowired
    protected JsonMapper jsonMapper;

    protected String getAdminAuthToken() {
        return getAuthToken(ADMIN_EMAIL, ADMIN_PASSWORD);
    }

    protected String getUserAuthToken() {
        return getAuthToken(USER_EMAIL, USER_PASSWORD);
    }
    
    protected String getAuthToken(String email, String password) {
        //logic to generate JWT token
        return "jwt-token";
    }
}
```

## Sample RestController Test

```java
package dev.sivalabs.projectname.users.rest;

import static org.assertj.core.api.Assertions.assertThat;

import dev.sivalabs.projectname.BaseIT;
import dev.sivalabs.projectname.users.rest.dto.RegisterUserResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.client.ExchangeResult;

class UserControllerTests extends BaseIT {

    @Test
    void shouldRegisterUserSuccessfully() {
        RegisterUserResponse response = restTestClient
                .post()
                .uri("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .body("""
                        {
                          "fullName":"User123",
                          "email":"user123@gmail.com",
                          "password":"Secret@121212"
                        }
                        """)
                .exchange()
                .expectStatus()
                .isCreated()
                .returnResult(RegisterUserResponse.class)
                .getResponseBody();

        assertThat(response).isNotNull();
        assertThat(response.fullName()).isEqualTo("User123");
        assertThat(response.email()).isEqualTo("user123@gmail.com");
        assertThat(response.role().name()).isEqualTo("ROLE_USER");
    }

    @ParameterizedTest
    @CsvSource({
        ",user1@gmail.com,password123,FullName",
        "user1,,password123,Email",
        "user1,user1@gmail.com,,Password",
    })
    void shouldNotRegisterWithoutRequiredFields(String fullName, String email, String password, String errorFieldName) {

        record ReqBody(String fullName, String email, String password) {}
        
        ExchangeResult exchangeResult = restTestClient
                .post()
                .uri("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .body(new ReqBody(fullName, email, password))
                .exchange()
                .expectStatus()
                .isBadRequest()
                .returnResult();

        String responseJson = new String(exchangeResult.getResponseBodyContent());
        assertThat(responseJson).contains("%s is required".formatted(errorFieldName));
    }

    @Test
    void shouldUpdateUserProfile() {
        restTestClient
                .put()
                .uri("/api/users/me")
                .headers(h -> h.setBearerAuth(getUserAuthToken()))
                .contentType(MediaType.APPLICATION_JSON)
                .body("""
                        {
                          "fullName": "Siva Updated"
                        }
                        """)
                .exchange()
                .expectStatus()
                .isOk();
    }

    @Test
    void shouldNotRegisterUserWithDuplicateEmail() {
        restTestClient
                .post()
                .uri("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .body("""
                        {
                          "fullName":"New User",
                          "email":"siva@gmail.com",
                          "password":"Secret@121212"
                        }
                        """)
                .exchange()
                .expectStatus()
                .isBadRequest();
    }

    @Test
    void shouldNotUpdateUserWithoutAuthentication() {
        restTestClient
                .put()
                .uri("/api/users/me")
                .contentType(MediaType.APPLICATION_JSON)
                .body("""
                        {
                          "fullName": "Updated Name"
                        }
                        """)
                .exchange()
                .expectStatus()
                .isUnauthorized();
    }
}
```