# Spring WebMVC REST APIs 

The following are key principles to follow while creating REST APIs using Spring Web MVC:

- Use **converters** to bind `@PathVariable` and `@RequestParam` to Value Objects
- Use **Jackson** for `@RequestBody` binding to Request Objects with Value Object properties
- Use `@JsonUnwrapped` to map flattened JSON to nested objects
- Validate with `@Valid` annotation
- Return appropriate HTTP status codes
- Delegate to services for business logic execution
- Implement Global Exception Handler using `@RestControllerAdvice` and return `ProblemDetails` type response

### Converter for PathVariable/RequestParam Binding

```java
import org.springframework.core.convert.converter.Converter;
import org.springframework.stereotype.Component;

@Component
public class StringToEventCodeConverter implements Converter<String, EventCode> {

    @Override
    public EventCode convert(String source) {
        return new EventCode(source);
    }
}
```

This allows Spring MVC to automatically convert path variables like `/{eventCode}` from String to `EventCode`:

```java
@GetMapping("/{eventCode}")
ResponseEntity<EventVM> findEventByCode(@PathVariable EventCode eventCode) {
    // eventCode is already an EventCode object, not a String
}
```

### Binding primitives to Request Bodies with Value Objects
Use `@JsonValue` and `@JsonCreator` annotations to bind primitives to Request Bodies with Value Objects.

**EventCode Value Object:**

```java
import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;
import jakarta.validation.constraints.NotBlank;

public record EventCode(
        @JsonValue 
        @NotBlank(message = "Event code cannot be null or empty")
        String code
) {
    @JsonCreator
    public EventCode {
        if (code == null || code.trim().isEmpty()) {
            throw new IllegalArgumentException("Event code cannot be null");
        }
    }

    public static EventCode of(String code) {
        return new EventCode(code);
    }
}
```

**CreateEventRequest Request Payload:**

```java
record CreateEventRequest(
        @Valid EventCode code
        // ... other properties
) {
}
```

Spring MVC will automatically bind the `code` property from the JSON payload to `EventCode` object.

```json
{
  "code": "ABSHDJFSD",
  "property-1": "value-1",
  "property-n": "value-n"
}
```

### Binding flattened JSON to Nested Objects
Use `@JsonUnwrapped` and `@JsonCreator(mode = JsonCreator.Mode.PROPERTIES)` annotations to map flattened JSON to nested objects.

```java
import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record EventDetails(
        @NotBlank(message = "Title is required")
        @Size(min = 3, max = 200, message = "Title must be between 3 and 200 characters")
        String title,

        @NotBlank(message = "Description is required")
        @Size(max = 10000, message = "Description cannot exceed 10000 characters")
        String description,

        @Size(max = 500, message = "Image URL cannot exceed 500 characters")
        @Pattern(regexp = "^https?://.*", message = "Image URL must be a valid HTTP/HTTPS URL")
        String imageUrl) {

    @JsonCreator(mode = JsonCreator.Mode.PROPERTIES)
    public EventDetails(
            @JsonProperty("title") String title,
            @JsonProperty("description") String description,
            @JsonProperty("imageUrl") String imageUrl
    ) {
        this.title = AssertUtil.requireNotNull(title, "title cannot be null");
        this.description = AssertUtil.requireNotNull(description, "description cannot be null");
        this.imageUrl = imageUrl;
    }

    public static EventDetails of(String title, String description, String imageUrl) {
        return new EventDetails(title, description, imageUrl);
    }
}
```

**CreateEventRequest Request Payload:**

```java
record CreateEventRequest(
        @Valid EventCode code,
        @JsonUnwrapped @Valid EventDetails details
        // ... other properties
) {
}
```

Spring MVC will automatically bind the `title`, `description` and `imageUrl` property values 
from the JSON payload to `EventDetails` object.

```json
{
  "code": "ABSHDJFSD",
  "title": "Spring Boot Workshop",
  "description": "Learn Spring Boot best practices",
  "imageUrl": "https://example.com/image.jpg",
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
import dev.sivalabs.meetup4j.shared.DomainException;
import dev.sivalabs.meetup4j.shared.ResourceNotFoundException;
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
        return ResponseEntity.status(UNPROCESSABLE_CONTENT).body(problemDetail);
    }

    @ExceptionHandler(DomainException.class)
    public ProblemDetail handle(DomainException e) {
        log.info("Bad request", e);
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(BAD_REQUEST, e.getMessage());
        problemDetail.setTitle("Bad Request");
        problemDetail.setProperty("errors", List.of(e.getMessage()));
        return problemDetail;
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ProblemDetail handle(ResourceNotFoundException e) {
        log.error("Resource not found", e);
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(NOT_FOUND, e.getMessage());
        problemDetail.setTitle("Resource Not Found");
        problemDetail.setProperty("errors", List.of(e.getMessage()));
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
  "detail": "Cannot cancel events that have already started",
  "errors": [
    "Cannot cancel events that have already started"
  ]
}
```

**Resource Not Found (404):**
```json
{
  "type": "about:blank",
  "title": "Resource Not Found",
  "status": 404,
  "detail": "Event not found with code: ABC123",
  "errors": [
    "Event not found with code: ABC123"
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
