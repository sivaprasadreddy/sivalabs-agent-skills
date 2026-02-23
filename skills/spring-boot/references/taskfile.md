# Taskfile

[Task](https://taskfile.dev/) is a cross-platform utility for executing tasks defined in a YAML file. 
It provides a simple and intuitive way to define and run tasks, making it easier to automate repetitive tasks and streamline workflows.

## Installation

```shell
$ brew install go-task
```

## Taskfile

Create `Taskfile.yml` file containing the common tasks for working with a Spring Boot application.

```yaml
version: '3'

vars:
  GOOS: "{{default OS .GOOS}}"
  MVNW: '{{if eq .GOOS "windows"}}mvnw.cmd{{else}}./mvnw{{end}}'
  SLEEP_CMD: '{{if eq .GOOS "windows"}}timeout{{else}}sleep{{end}}'
  BACKEND_DIR: "."
  COMPOSE_DIR: "."
  COMPOSE_FILE: "{{.COMPOSE_DIR}}/compose.yml"

tasks:
  default:
    cmds:
      - task: build

  build:
    dir: "{{.BACKEND_DIR}}"
    desc: Run all the tests and build the application
    cmds:
      - "{{.MVNW}} clean spotless:apply verify"

  build_docker_image:
    dir: "{{.BACKEND_DIR}}"
    desc: Build Docker Image using Buildpacks
    cmds:
      - "{{.MVNW}} clean compile spring-boot:build-image -DskipTests"

  start:
    desc: Start the application
    deps: [ build_docker_image ]
    cmds:
      - docker compose -f "{{.COMPOSE_FILE}}" up --force-recreate -d

  stop:
    desc: Stop the application
    cmds:
      - docker compose -f "{{.COMPOSE_FILE}}" stop
      - docker compose -f "{{.COMPOSE_FILE}}" rm -f

  restart:
    desc: Restarts the application
    cmds:
      - task: stop
      - task: sleep
      - task: start

  sleep:
    desc: Sleeps for the given number of seconds
    vars:
      DURATION: "{{default 5 .DURATION}}"
    cmds:
      - "{{.SLEEP_CMD}} {{.DURATION}}"
```