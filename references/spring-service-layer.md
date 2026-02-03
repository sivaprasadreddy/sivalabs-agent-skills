# Spring Business Logic Layer

The following are key principles to follow while creating Spring Service layer components:

- Create separate classes for Command and Query operations
- Use `@Transactional` for all write operations
- Use `@Transactional(readOnly = true)` for all read operations
- Create dedicated Command and Query objects for service method inputs
- Create dedicated Result objects for service method outputs
- Follow naming conventions of `XCmd`, `XQuery` and `XResult`

### Example: EventCommandService (Command Service for write operations)

```java
@Service
@Transactional
public class EventCommandService {
private final EventRepository eventRepository;
private final SpringEventPublisher eventPublisher;

    EventCommandService(EventRepository eventRepository, 
                        SpringEventPublisher eventPublisher) {
        this.eventRepository = eventRepository;
        this.eventPublisher = eventPublisher;
    }

    public EventCode createEvent(CreateEventCmd cmd) {
        var event = EventEntity.createDraft(
                cmd.details(),
                cmd.schedule(),
                cmd.type(),
                cmd.ticketPrice(),
                cmd.capacity(),
                cmd.location()
        );

        eventRepository.save(event);
        eventPublisher.publish(new EventCreated(
            event.getCode().code(),
            event.getDetails().title(),
            event.getDetails().description()
        ));
        return event.getCode();
    }

    public void cancelEvent(CancelEventCmd cmd) {
        EventEntity event = eventRepository.getByCode(cmd.eventCode());
        if(event.cancel()) {
            eventRepository.save(event);
            eventPublisher.publish(new EventCancelled(
                event.getCode().code(),
                event.getDetails().title(),
                event.getDetails().description()
            ));
        }
    }

    //...
    //...
}
```


### Example 2: EventQueryService (Query Service for read operations)

```java
@Service
@Transactional(readOnly = true)
public class EventQueryService {
    private final EventRepository eventRepository;
    private final EventMapper eventMapper;

    EventQueryService(EventRepository eventRepository, EventMapper eventMapper) {
        this.eventRepository = eventRepository;
        this.eventMapper = eventMapper;
    }

    public List<EventVM> getUpcomingEvents() {
        return eventRepository.findUpcomingEvents(Instant.now())
                .stream().map(eventMapper::toEventVM).toList();
    }

    public EventVM getByCode(EventCode eventCode) {
        var event = eventRepository.getByCode(eventCode);
        return eventMapper.toEventVM(event);
    }

    //...
}
```

**ViewModel Example:**

```java
public record EventVM(
    Long id,
    String code,
    String title,
    String description,
    Instant startDatetime,
    Instant endDatetime,
    //...
    //...
    String venue,
    String virtualLink,
    int registeredUsersCount) {}
```

**Mapper Example:**

```java
@Component
class EventMapper {
    EventVM toEventVM(EventEntity event) {
        return new EventVM(
            event.getId().id(),
            event.getCode().code(),
            event.getDetails().title(),
            event.getDetails().description(),
            //...
            event.getLocation().virtualLink(),
            event.getRegistrationsCount()
        );
    }
}
```
