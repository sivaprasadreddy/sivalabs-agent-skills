# Spring WebMVC REST APIs

The following are key principles to follow while creating REST APIs using Spring Web MVC:

- Use **converters** to bind `@PathVariable` and `@RequestParam` to Value Objects
- Use **Jackson** for `@RequestBody` binding to Request Objects with Value Object properties
- Validate with `@Valid` annotation
- Return appropriate HTTP status codes
- Delegate to services for business logic execution
- Implement Global Exception Handler using `@RestControllerAdvice` and return `ProblemDetails` type response

### Converter for PathVariable/RequestParam Binding

```java
import org.springframework.core.convert.converter.Converter;
import org.springframework.stereotype.Component;

@Component
public class StringToUserIdConverter implements Converter<String, UserId> {

    @Override
    public UserId convert(String source) {
        return new UserId(source);
    }
}
```

This allows Spring MVC to automatically convert path variables like `/{userId}` from String to `UserId`:

```java
@GetMapping("/{userId}")
ResponseEntity<UserVM> findUserById(@PathVariable UserId userId) {
    // userId is already an UserId object, not a String
}
```

### Binding primitives to Request Bodies with Value Objects
Use `@JsonValue` and `@JsonCreator` annotations to bind primitives to Request Bodies with Value Objects.

**UserId Value Object:**

```java
import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;
import jakarta.validation.constraints.NotBlank;

public record UserId(
        @JsonValue 
        @NotBlank(message = "User id cannot be null or empty")
        String id
) {
    @JsonCreator
    public UserId {
        if (id == null || id.trim().isEmpty()) {
            throw new IllegalArgumentException("User id cannot be null");
        }
    }

    public static UserId of(String id) {
        return new UserId(id);
    }
}
```

**CreateUserRequest Request Payload:**

```java
record CreateUserRequest(
        @Valid UserId userId
        // ... other properties
) {
}
```

Spring MVC will automatically bind the `userId` property from the JSON payload to `UserId` object.

```json
{
  "userId": "ABSHDJFSD",
  "property-1": "value-1",
  "property-n": "value-n"
}
```

### Global Exception Handler
Create a centralized exception handler that returns **ProblemDetail** responses.

Create a class `GlobalExceptionHandler` by following the following key principles:

- Use `@RestControllerAdvice`
- Extend `ResponseEntityExceptionHandler`
- Return `ProblemDetail` for RFC 7807 compliance
- Map different exceptions to appropriate HTTP status codes
- Include validation errors in response
- Hide internal details in production

### Example: GlobalExceptionHandler

```java
import dev.sivalabs.onepoint.shared.DomainException;
import dev.sivalabs.onepoint.shared.ResourceNotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.support.DefaultMessageSourceResolvable;
import org.springframework.core.env.Environment;
import org.springframework.http.*;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

import java.time.Instant;
import java.util.Arrays;
import java.util.List;

import static org.springframework.http.HttpStatus.NOT_FOUND;
import static org.springframework.http.HttpStatus.BAD_REQUEST;
import static org.springframework.http.HttpStatus.INTERNAL_SERVER_ERROR;

@RestControllerAdvice
class GlobalExceptionHandler extends ResponseEntityExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);
    private final Environment environment;

    GlobalExceptionHandler(Environment environment) {
        this.environment = environment;
    }

    @Override
    public ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException ex, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        log.error("Validation error", ex);
        var errors = ex.getAllErrors().stream()
                .map(DefaultMessageSourceResolvable::getDefaultMessage)
                .toList();

        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(BAD_REQUEST, ex.getMessage());
        problemDetail.setTitle("Validation Error");
        problemDetail.setProperty("errors", errors);
        problemDetail.setProperty("timestamp", Instant.now());
        return ResponseEntity.status(UNPROCESSABLE_CONTENT).body(problemDetail);
    }

    @ExceptionHandler(DomainException.class)
    public ProblemDetail handle(DomainException e) {
        log.warn("Bad request", e);
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(BAD_REQUEST, e.getMessage());
        problemDetail.setTitle("Bad Request");
        problemDetail.setProperty("errors", List.of(e.getMessage()));
        problemDetail.setProperty("timestamp", Instant.now());
        return problemDetail;
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ProblemDetail handle(ResourceNotFoundException e) {
        log.error("Resource not found", e);
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(NOT_FOUND, e.getMessage());
        problemDetail.setTitle("Resource Not Found");
        problemDetail.setProperty("errors", List.of(e.getMessage()));
        problemDetail.setProperty("timestamp", Instant.now());
        return problemDetail;
    }

    @ExceptionHandler(Exception.class)
    ProblemDetail handleUnexpected(Exception e) {
        logger.error("Unexpected exception occurred", e);

        // Don't expose internal details in production
        String message = "An unexpected error occurred";
        if (isDevelopmentMode()) {
            message = e.getMessage();
        }

        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(INTERNAL_SERVER_ERROR, message);
        problemDetail.setProperty("timestamp", Instant.now());
        return problemDetail;
    }

    private boolean isDevelopmentMode() {
        List<String> profiles = Arrays.asList(environment.getActiveProfiles());
        return profiles.contains("dev") || profiles.contains("local");
    }
}
```

#### Error Response Examples

**Validation Error (400):**
```json
{
  "type": "about:blank",
  "title": "Validation Error",
  "status": 400,
  "detail": "Validation failed for argument...",
  "errors": [
    "Title is required",
    "Email must be valid"
  ]
}
```

**Domain Exception (400):**
```json
{
  "type": "about:blank",
  "title": "Bad Request",
  "status": 400,
  "detail": "Cannot update user details",
  "errors": [
    "Email is already exist"
  ]
}
```

**Resource Not Found (404):**
```json
{
  "type": "about:blank",
  "title": "Resource Not Found",
  "status": 404,
  "detail": "User not found with id: ABC123",
  "errors": [
    "User not found with id: ABC123"
  ]
}
```

**Internal Server Error (500):**
```json
{
  "type": "about:blank",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "An unexpected error occurred",
  "timestamp": "2024-01-15T10:30:00Z"
}
```
