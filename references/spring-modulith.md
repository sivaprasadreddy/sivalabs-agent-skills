# Spring Modulith

Follow these principles when using Spring Modulith:

- Add the following BOM with the latest version of Spring Modulith
    ```xml
    <properties>
        <spring-modulith.version>2.0.3</spring-modulith.version>
    </properties>
  
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.modulith</groupId>
                <artifactId>spring-modulith-bom</artifactId>
                <version>${spring-modulith.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>
  
    <dependencies>
        <dependency>
            <groupId>org.springframework.modulith</groupId>
            <artifactId>spring-modulith-starter-core</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.modulith</groupId>
            <artifactId>spring-modulith-events-api</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.modulith</groupId>
            <artifactId>spring-modulith-starter-jdbc</artifactId>
        </dependency>
  
        <dependency>
            <groupId>org.springframework.modulith</groupId>
            <artifactId>spring-modulith-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
    ```

- Configure Spring Modulith configuration properties in `application.properties` file
    ```properties
    spring.modulith.events.jdbc.schema-initialization.enabled=true
    # completion-mode options: update | delete | archive
    spring.modulith.events.completion-mode=update
    spring.modulith.events.republish-outstanding-events-on-restart=true
    ```

- Write ModularityTest in the base package to verify the Spring Modulith rules.
    ```java
    package dev.sivalabs.projectname;

    import org.junit.jupiter.api.Test;
    import org.springframework.modulith.core.ApplicationModules;
    import org.springframework.modulith.docs.Documenter;
    
    class ModularityTest {
        static ApplicationModules modules = ApplicationModules.of(Application.class);
    
        @Test
        void verifiesModularStructure() {
            modules.verify();
            new Documenter(modules).writeDocumentation();
        }
    }
    ```
  
- Make `shared` module as `OPEN` type module by creating `package-info.java` inside `shared` package as follows:
    ```java
    @ApplicationModule(type = ApplicationModule.Type.OPEN)
    package dev.sivalabs.projectname.shared;
    
    import org.springframework.modulith.ApplicationModule;
    ```
  
- Enable access to domain models as NamedInterfaces by creating `package-info.java` inside `shared` package as follows:
    ```java
    @NamedInterface("modulename-models")
    package dev.sivalabs.projectname.modulename.domain.models;
    
    import org.springframework.modulith.NamedInterface;
    ```
  
- Make JPA entities, Repositories, Mappers as package-protected visibility (non-public).
- Create a `{Module}API.java` in the module's root package to expose only public API method and delegate the logic to services.
- Make sure there are no cyclic-dependencies between modules.
- For asynchronous communication use event-driven processing with Spring Modulith's event infrastructure.
    ```java
    import org.springframework.modulith.events.ApplicationModuleListener;

    @Component
    class OrderCreatedEventHandler {
    
       @ApplicationModuleListener
       void handle(OrderCreatedEvent event) {
             log.info("Received order created event: {}", event);
       }
    }
    ```