# Spring Boot Docker Compose Support for Development

This guide provides instructions on how to use Spring Boot Docker Compose support for local development. 

## Add Maven Dependency

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-docker-compose</artifactId>
    <scope>runtime</scope>
    <optional>true</optional>
</dependency>
```

## Add Required Docker Compose Services Configuration

### PostgreSQL

```yaml
services:
  postgres:
    image: 'postgres:18-alpine'
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
    ports:
      - '5432'
```

### Redis

```yaml
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379"
```

### Grafana LGTM

```yaml
services:
  grafana-lgtm:
    image: 'grafana/otel-lgtm:0.17.0'
    ports:
      - '3000:3000'
      - '4317:4317'
      - '4318:4318'
```

### Mailpit for JavaMail

```yaml
services:
  mailpit:
    image: axllent/mailpit:v1.29
    ports:
      - "1025:1025"
      - "8025:8025"
```