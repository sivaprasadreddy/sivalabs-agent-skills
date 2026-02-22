# Spring Business Logic Layer

The following are key principles to follow while creating Spring Service layer components:

- Create service classes that perform a Unit Of Work
- Use `@Transactional` for all write operations
- Use `@Transactional(readOnly = true)` for all read operations
- Create dedicated Command and Query objects for service method inputs
- Create dedicated Result objects for service method outputs
- Follow naming conventions of `XCmd`, `XQuery` and `XResult`
- Create a marker interface `DomainEvent` and all Domain event classes should extend `DomainEvent`
- Create an event publisher class `SpringEventPublisher` to publish domain events that extend `DomainEvent` interface


## DomainEvent.java

```java
package dev.sivalabs.projectname.shared.models;

public interface DomainEvent{}
```


## SpringEventPublisher

```java
package dev.sivalabs.projectname.shared.services;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import dev.sivalabs.projectname.shared.models.DomainEvent;

@Service
public class SpringEventPublisher {
    private final ApplicationEventPublisher publisher;

    public SpringEventPublisher(ApplicationEventPublisher publisher) {
        this.publisher = publisher;
    }

    public void publish(DomainEvent event) {
        publisher.publishEvent(event);
    }
}
``` 

### Example: UserService

```java
@Service
public class UserService {
    private final UserRepository userRepository;
    private final UserMapper userMapper;
    private final SpringEventPublisher eventPublisher;

    UserService(UserRepository userRepository,
                UserMapper userMapper,
                SpringEventPublisher eventPublisher) {
        this.userRepository = userRepository;
        this.userMapper = userMapper;
        this.eventPublisher = eventPublisher;
    }

    @Transactional
    public UserId createUser(CreateUserCmd cmd) {
        var user = UserEntity.create(
                cmd.firstName(),
                cmd.lastName(),
                cmd.email(),
                cmd.password()
        );
        userRepository.save(user);
        eventPublisher.publish(new UserCreated(
            user.getEmail(),
            user.getFirstName(),
            user.getLastName()
        ));
        return user.getId();
    }

    @Transactional(readOnly = true)
    public List<UserVM> searchUsers(String query) {
        return userRepository.findByNameContainingEqualsIgnoreCase(query)
                .stream().map(userMapper::toUserVM).toList();
    }

    @Transactional(readOnly = true)
    public UserVM getByEmail(String email) {
        var user = userRepository.getByEmail(email);
        return userMapper.toUserVM(user);
    }

    //...
}
```

**UserCreated Event:**

```java
public record UserCreated(String email, String firstName, String lastName) implements DomainEvent {}
```

**ViewModel Example:**

```java
public record UserVM(
    String id,
    String fullName,
    String email,
    String role) {}
```

**Mapper Example:**

```java
@Component
class UserMapper {
    UserVM toUserVM(UserEntity user) {
        return new UserVM(
            user.getId().id(),
            user.getFullName(),
            user.getEmail(),
            user.getRole().name()
        );
    }
}
```
