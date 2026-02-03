# Spring Data JPA

The following are key principles to follow while using Spring Data JPA:

- Create repositories **only for aggregate roots**
- Use `@Query` with **JPQL** for custom queries
- Prefer **meaningful method names** over long Spring Data JPA finder methods
- Use **constructor expressions** or **Projections** for read operations
- Use **default methods** for convenience operations

### Example: EventRepository

**File:** `events/domain/EventRepository.java`

```java
interface EventRepository extends JpaRepository<EventEntity, EventId> {

    @Query("""
            SELECT e FROM EventEntity e
            WHERE e.startDatetime > :now
            ORDER BY e.startDatetime ASC
            """)
    List<EventEntity> findUpcomingEvents(@Param("now") Instant now);

    @Query("""
            SELECT e FROM EventEntity e
            WHERE e.code = :code
            """)
    Optional<EventEntity> findByCode(@Param("code") EventCode code);

    // Convenience methods using default interface methods
    default EventEntity getByCode(EventCode eventCode) {
        return this.findByCode(eventCode)
                .orElseThrow(() -> new ResourceNotFoundException("Event not found with code: " + eventCode));
    }
}
```

## Enable JPA Auditing
Enable JPA Auditing support to automatically populate `createdAt` and `updatedAt` fields.

- Add `@CreatedDate` and `@LastModifiedDate` annotations to your `BaseEntity` class.
- Add `@EntityListeners(AuditingEntityListener.class)` to your `BaseEntity` class.
- Create a Spring `@Configuration` class and add `@EnableJpaAuditing` annotation.

```java
import jakarta.persistence.Column;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.MappedSuperclass;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;

@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

    @Column(name = "created_at", nullable = false, updatable = false)
    @CreatedDate
    protected Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    @LastModifiedDate
    protected Instant updatedAt;

    // Getters and setters
}
```

**Enable JPA Auditing** in your application configuration:

```java
@Configuration
@EnableJpaAuditing
public class JpaConfig {
}
```
