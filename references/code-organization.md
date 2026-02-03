# Spring Boot Application Package Structure

Follow a **domain-driven, modular architecture** where packages are organized by 
**business modules** rather than technical layers.

### Recommended Example Package Structure

```
dev.sivalabs.projectname/
├── Application                      # Main Spring Boot entrypoint class
├── shared/                          # Cross-cutting concerns
│   ├── BaseEntity.java
│   ├── DomainException.java
│   ├── ResourceNotFoundException.java
│   └── SpringEventPublisher.java
│
├── events/                          # Events module (bounded context)
│   ├── domain/                      # Domain logic
│   │   ├── models/                  # ViewModels for read operations
│   │   │   └── EventVM.java
│   │   ├── vo/                      # Value Objects
│   │   │   ├── EventId.java
│   │   │   ├── EventCode.java
│   │   │   ├── EventDetails.java
│   │   │   ├── Schedule.java
│   │   │   ├── TicketPrice.java
│   │   │   ├── Capacity.java
│   │   │   └── EventLocation.java
│   │   ├── events/                  # Domain events
│   │   │   ├── EventCreated.java
│   │   │   ├── EventPublished.java
│   │   │   └── EventCancelled.java
│   │   ├── EventEntity.java         # Aggregate root
│   │   ├── EventRepository.java     # Repository interface
│   │   ├── EventService.java        # Write operations
│   │   ├── EventQueryService.java   # Read operations
│   │   ├── EventMapper.java         # Domain to ViewModel mapper
│   │   ├── CreateEventCmd.java      # Command
│   │   ├── PublishEventCmd.java
│   │   └── InvalidEventCreationException.java
│   ├── rest/                        # REST API layer
│   │   ├── converters/              # Type converters
│   │   │   └── StringToEventCodeConverter.java
│   │   ├── EventsController.java
│   │   ├── CreateEventRequest.java  # HTTP Request DTO
│   │   └── CreateEventResponse.java # HTTP Response DTO
│   └── EventsAPI.java               # Module's public API (facade)
│
├── registrations/                   # Registrations module
│   ├── domain/
│   │   ├── vo/
│   │   │   ├── RegistrationId.java
│   │   │   ├── RegistrationCode.java
│   │   │   └── Email.java
│   │   ├── EventRegistrationEntity.java
│   │   ├── RegistrationRepository.java
│   │   ├── EventRegistrationService.java
│   │   ├── EventRegistrationQueryService.java
│   │   └── RegisterAttendeeCmd.java
│   └── rest/
│       ├── converters/
│       ├── EventRegistrationController.java
│       └── EventRegistrationRequest.java
│
└── config/
    └── GlobalExceptionHandler.java
```

### Naming Conventions

| Type                  | Convention           | Example                                                       |
|-----------------------|----------------------|---------------------------------------------------------------|
| **Entities**          | `*Entity`            | `EventEntity`, `EventRegistrationEntity`                      |
| **Value Objects**     | Domain name (record) | `Email`, `EventCode`, `EventId`                               |
| **Commands**          | `*Cmd`               | `CreateEventCmd`, `PublishEventCmd`                           |
| **Command Response**  | `*Result`            | `LoginResult`, `RegistrationResult`                           |
| **ViewModels**        | `*VM`                | `EventVM`, `RegistrationVM`                                   |
| **HTTP Request**      | `*Request`           | `CreateEventRequest`, `EventRegistrationRequest`              |
| **HTTP Response**     | `*Response`          | `CreateEventResponse`, `EventRegistrationResponse`            |
| **Repositories**      | `*Repository`        | `EventRepository`, `RegistrationRepository`                   |
| **Services (Write)**  | `*Service`           | `EventService`, `EventRegistrationService`                    |
| **Services (Read)**   | `*QueryService`      | `EventQueryService`, `EventRegistrationQueryService`          |
| **Domain Exceptions** | `*Exception`         | `InvalidEventCreationException`, `EventCancellationException` |
| **Module API**        | `*API`               | `EventsAPI`                                                   |
