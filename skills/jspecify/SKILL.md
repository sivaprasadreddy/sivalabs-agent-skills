---
name: jspecify-skill
description: >
  Use this skill when asked to perform any of the following actions in a Java project:
    - To add jspecify support
    - To prevent NullPointerExceptions
    - To better handle Nullability

  This skill will add jspecify dependency, configure Maven or Gradle build to automatically use jspecify for checking Nullability issues.
---

Jspecify provides a set of annotations to explicitly declare the nullness expectations of the Java code.

## Add jSpecify support in Maven projects
If you are using Maven, then add the jspecify dependency in `pom.xml`.
In `pom.xml`, update or add the `nullability-maven-plugin`, to include the following configuration.

```xml
<dependencies>
    <dependency>
        <groupId>org.jspecify</groupId>
        <artifactId>jspecify</artifactId>
        <version>1.0.0</version>
    </dependency>
</dependencies>

<build>
    <plugins>
        <plugin>
            <groupId>am.ik.maven</groupId>
            <artifactId>nullability-maven-plugin</artifactId>
            <version>0.4.2</version>
            <extensions>true</extensions>
            <configuration>
                <checking>tests</checking>
                <outputDirectory>${project.basedir}/src/main/java</outputDirectory>
                <testOutputDirectory>${project.basedir}/src/test/java</testOutputDirectory>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>configure</goal>
                        <goal>generate-package-info</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

## Add jSpecify support in Gradle projects
If you are using Gradle, then add the jspecify dependency.
In `build.gradle` or `build.gradle.kts`, update or add the following jspecify configuration.

```groovy
plugins {
    id("net.ltgt.errorprone") version "5.1.0"
    id("net.ltgt.nullaway") version "3.1.0"
}

tasks.withType(JavaCompile).configureEach {
    options.errorprone {
        disableAllChecks = true // Other error prone checks are disabled
        error("RequireExplicitNullMarking") // Require @NullMarked or @NullUnmarked on everything
        nullaway {
            error()
        }
    }
    // Keep a JDK 25 baseline
    options.release = 25
}

nullaway {
    onlyNullMarked = true
    jspecifyMode = true
}

dependencies {
    implementation("org.jspecify:jspecify:1.0.0")
    errorprone("com.google.errorprone:error_prone_core:2.50.0")
    errorprone("com.uber.nullaway:nullaway:0.13.7")
}
```

## Add @NullMarked to package-info.java files
In every java package under the application main source code (`src/main/java`), 
create `package-info.java` if not exists already, and add the `@NullMarked` annotation as follows:

```java
@org.jspecify.annotations.NullMarked
package com.mycompnay.myproject;
```

If `package-info.java` file already exists, update the file to add `@org.jspecify.annotations.NullMarked` annotation.
DO NOT REMOVE ANY OTHER EXISTING CODE IN `package-info.java` FILE.

## Verify jSpecify support
If python is installed, after adding the jSpecify support, run `scripts/verify_nullmarked.py` 
to check if all non-empty packages has `package-info.java` file or not.

## Migrating an existing codebase from other annotation libraries

If the project already uses another nullability annotation library (JSR-305 / `javax`, Jakarta,
JetBrains, Spring, Android, FindBugs/SpotBugs, Checker Framework, or Eclipse JDT), migrate those
annotations to JSpecify **before** adding `@NullMarked`. The OpenRewrite `MigrateToJSpecify` recipe
automates the common cases (javax, Jakarta, JetBrains, Micrometer, Micronaut); the rest are a short
manual mapping. See [references/annotation-migration.md](references/annotation-migration.md).

## Incremental adoption for large codebases

Flipping every package to `@NullMarked` at once is impractical on a large or legacy codebase.
`@NullUnmarked` lets you enforce NullAway on a growing perimeter while the rest stays untouched.
Because the build above enables `OnlyNullMarked` mode, packages without `@NullMarked` are simply
ignored — so adoption is driven purely by adding markers, one package at a time. Strategies,
progress tracking, common NullAway errors, and redundant null-guard removal are in
[references/incremental-adoption.md](references/incremental-adoption.md).

## Kotlin interop (optional)

If the project also has Kotlin sources, the Kotlin compiler (K2) reads JSpecify annotations on Java
APIs and surfaces accurate nullability instead of platform types. See
[references/kotlin-interop.md](references/kotlin-interop.md).
