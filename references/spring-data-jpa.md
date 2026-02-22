# Spring Data JPA

- [Key principles](#key-principles)
- [IdentityGenerator (TSID)](#identitygenerator)
- [Value Object for Primary Key](#value-object-for-primary-key)
- [JPA Auditing](#use-jpa-auditing-support)
- [AssertUtil](#assertutil-class-to-validate-input-parameters)
- [Example entity](#example-jpa-entity-class)
- [Example repository](#example-userrepository)

## Key principles

Follow these principles when using Spring Data JPA:

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
- Create repositories **only for aggregate roots**
- Use `@Query` with **JPQL** for custom queries
- Prefer **meaningful method names** over long Spring Data JPA finder methods
- Use **constructor expressions** or **Projections** for read operations
- Use **default methods** for convenience operations

## IdentityGenerator

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

## Value Object for Primary Key

```java
public record UserId(String id) {
    public UserId {
        if (id == null || id.trim().isBlank()) {
            throw new IllegalArgumentException("User id cannot be null or empty");
        }
    }

    public static UserId of(String id) {
        return new UserId(id);
    }

    public static UserId generate() {
        return new UserId(IdGenerator.generateString());
    }
}
```

## Use JPA Auditing Support

- Add `@CreatedDate` and `@LastModifiedDate` annotations to your `BaseEntity` class.
- Add `@EntityListeners(AuditingEntityListener.class)` to your `BaseEntity` class.
- Create a Spring `@Configuration` class and add `@EnableJpaAuditing` annotation.

**File:** `BaseEntity.java`

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
    
    @Version
    private int version;
    
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

**Enable JPA Auditing** in your application configuration:

```java
@Configuration
@EnableJpaAuditing
public class JpaConfig {
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
@Table(name = "users")
class UserEntity extends BaseEntity {

    @EmbeddedId
    @AttributeOverride(name = "id", column = @Column(name = "id", nullable = false))
    private UserId id;

    @Embedded
    @AttributeOverrides({
        @AttributeOverride(name = "addrLine1", column = @Column(name = "addr_line1", nullable = false)),
        @AttributeOverride(name = "addrLine2", column = @Column(name = "addr_line2")),
        @AttributeOverride(name = "city", column = @Column(name = "city"))
    })
    private Address address;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false)
    private Role role;

    //.. other fields


    // Protected constructor for JPA
    protected UserEntity() {}

    // Constructor with all required fields
    public UserEntity(UserId id,
                       Address address,
                       //...
                       Role role
                       ) {
        this.id = AssertUtil.requireNotNull(id, "Event id cannot be null");
        this.address = AssertUtil.requireNotNull(address, "Address cannot be null");
        this.role = AssertUtil.requireNotNull(role, "Role cannot be null");
        //...
    }

    // Factory method for creating new entities
    public static UserEntity create(Address address, Role role) {
        return new UserEntity(
                UserId.generate(),
                address,
                role);
    }

    public boolean isAdmin() {
        return role == Role.ROLE_ADMIN;
    }

    // Getters
}
```

### Example: UserRepository

**File:** `users/domain/repositories/UserRepository.java`

```java
interface UserRepository extends JpaRepository<UserEntity, UserId> {

    Optional<UserEntity> findByEmail(@Param("email") String email);

    // Convenience methods using default interface methods
    default UserEntity getByEmail(String email) {
        return this.findByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("User not found with email: " + email));
    }
}
```
