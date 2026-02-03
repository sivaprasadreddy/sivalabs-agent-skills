# JPA

The following are key principles to follow while using JPA:

- Create `BaseEntity` for audit fields(`createdAt`, `updatedAt`) and extend all entities from it
- Create a Value Object to represent the primary key and use `@EmbeddedId` annotation
- Create a **protected no-arg constructor** for JPA
- Create a **public constructor** with all required fields
- Validate state and throw exceptions for invalid inputs
- Explicitly define **table names** for all entities
- Explicitly define **column names** for all fields
- Use **enum types** for enum fields and `@Enumerated(EnumType.STRING)` annotation
- For logically related fields, create a Value Object to represent them
- When using value objects, embed them with `@Embedded` and `@AttributeOverrides`
- Add **domain methods** that operate on entity state
- Use **optimistic locking** with `@Version`

### IdentityGenerator

To use TSID, add the following dependency:

```xml
<dependency>
    <groupId>io.hypersistence</groupId>
    <artifactId>hypersistence-utils-hibernate-71</artifactId>
    <version>3.14.1</version>
</dependency>
```

Use TSID to generate IDs as follows:

```java
import io.hypersistence.tsid.TSID;

public class IdGenerator {
    private IdGenerator() {}

    public static String generateString() {
        return TSID.Factory.getTsid().toString();
    }
}
```

### Value Object for Primary Key

```java
public record EventId(String id) {
    public EventId {
        if (id == null || id.trim().isBlank()) {
            throw new IllegalArgumentException("Event id cannot be null or empty");
        }
    }

    public static EventId of(String id) {
        return new EventId(id);
    }

    public static EventId generate() {
        return new EventId(IdGenerator.generateString());
    }
}
```

### BaseEntity with Auditing Support

**File:** `BaseEntity.java`

```java
import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;

import java.time.Instant;

@MappedSuperclass
public abstract class BaseEntity {

    @Column(name = "created_at", nullable = false, updatable = false)
    protected Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    protected Instant updatedAt;

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}
```

### AssertUtil class to validate input parameters
Create a `AssertUtil` class with static methods to validate input parameters.

```java
public class AssertUtil {
    private AssertUtil() {}

    public static <T> T requireNotNull(T obj, String message) {
        if (obj == null)
            throw new IllegalArgumentException(message);
        return obj;
    }
}
```

### Example JPA Entity Class
While Creating a new JPA entity class, extend it from `BaseEntity`:

```java
import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "events")
class EventEntity extends BaseEntity {

    @EmbeddedId
    @AttributeOverride(name = "id", column = @Column(name = "id", nullable = false))
    private EventId id;

    @Embedded
    @AttributeOverrides({
        @AttributeOverride(name = "title", column = @Column(name = "title", nullable = false)),
        @AttributeOverride(name = "description", column = @Column(name = "description")),
        @AttributeOverride(name = "imageUrl", column = @Column(name = "image_url"))
    })
    private EventDetails details;

    @Enumerated(EnumType.STRING)
    @Column(name = "event_type", nullable = false)
    private EventType type;

    //.. other fields

    @Version
    private int version;

    // Protected constructor for JPA
    protected EventEntity() {}

    // Constructor with all required fields
    public EventEntity(EventId id,
                       EventCode code,
                       EventDetails details,
                       Schedule schedule,
                       EventType type,
                       //...
                       EventLocation location) {
        this.id = AssertUtil.requireNotNull(id, "Event id cannot be null");
        this.code = AssertUtil.requireNotNull(code, "Event code cannot be null");
        this.details = AssertUtil.requireNotNull(details, "Event details cannot be null");
        this.schedule = AssertUtil.requireNotNull(schedule, "Event schedule cannot be null");
        this.type = AssertUtil.requireNotNull(type, "Event type cannot be null");
        this.location = AssertUtil.requireNotNull(location, "Event location cannot be null");
        //...
    }

    // Factory method for creating new entities
    public static EventEntity createDraft(
            EventDetails details,
            Schedule schedule,
            EventType type,
            TicketPrice ticketPrice,
            Capacity capacity,
            EventLocation location) {

        return new EventEntity(
                EventId.generate(),
                EventCode.generate(),
                details,
                schedule,
                type,
                EventStatus.DRAFT,
                ticketPrice,
                capacity,
                location);
    }

    // Domain logic methods
    public boolean hasFreeSeats() {
        return capacity == null || capacity.value() == null || capacity.value() > registrationsCount;
    }

    public boolean isPublished() {
        return status == EventStatus.PUBLISHED;
    }

    // Getters
}
```
