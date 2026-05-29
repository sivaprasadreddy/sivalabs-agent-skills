---
name: jspecify-skill
description: Use this skill when asked to add jSpecify support in a Java project
---

Jspecify provides a set of annotations to explicitly declare the nullness expectations of the Java code.

## Add jSpecify support in Maven projects
If you are using Maven, add the jspecify dependency in `pom.xml`.
In single-module projects, add it to that module's `pom.xml`. In multi-module projects, add the dependency to each module's `pom.xml` that contains Java sources requiring jspecify, or declare the version in the parent POM's `<dependencyManagement>` and add module-level dependencies.
In `pom.xml`, update or add the `maven-compiler-plugin` configuration below.

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
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compiler-plugin</artifactId>
            <version>3.14.1</version>
            <configuration>
                <release>${maven.compiler.release}</release>
                <encoding>UTF-8</encoding>
                <fork>true</fork>
                <compilerArgs>
                    <arg>-XDcompilePolicy=simple</arg>
                    <arg>--should-stop=ifError=FLOW</arg>
                    <arg>-Xplugin:ErrorProne</arg>
                    <arg>-XepDisableAllChecks</arg>
                    <arg>-Xep:NullAway:ERROR</arg>
                    <arg>-XepOpt:NullAway:OnlyNullMarked</arg>
                    <arg>-XepOpt:NullAway:JSpecifyMode=true</arg>
                    <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED</arg>
                    <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED</arg>
                    <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED</arg>
                    <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.model=ALL-UNNAMED</arg>
                    <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED</arg>
                    <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED</arg>
                    <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED</arg>
                    <arg>-J--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED</arg>
                    <arg>-J--add-opens=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED</arg>
                    <arg>-J--add-opens=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED</arg>
                </compilerArgs>
                <annotationProcessorPaths>
                    <path>
                        <groupId>com.google.errorprone</groupId>
                        <artifactId>error_prone_core</artifactId>
                        <version>2.42.0</version>
                    </path>
                    <path>
                        <groupId>com.uber.nullaway</groupId>
                        <artifactId>nullaway</artifactId>
                        <version>0.12.12</version>
                    </path>
                </annotationProcessorPaths>
            </configuration>
        </plugin>
    </plugins>
</build>
```

## Add jSpecify support in Gradle projects
If you are using Gradle, add the jspecify dependency to the module(s) that contain Java sources requiring jspecify. In a multi-module Gradle build, apply this configuration in each module or use a shared convention plugin.
In `build.gradle` or `build.gradle.kts`, update or add the following jspecify configuration.

```groovy
plugins {
    id("net.ltgt.errorprone") version "4.3.0"
}

tasks.withType(JavaCompile).configureEach {
    options.errorprone {
        disableAllChecks = true // Other error prone checks are disabled
        option("NullAway:OnlyNullMarked", "true") // Enable nullness checks only in null-marked code
        error("NullAway") // bump checks from warnings (default) to errors
        option("NullAway:JSpecifyMode", "true") // https://github.com/uber/NullAway/wiki/JSpecify-Support
    }
    // Set this to your project's target Java major version, or use a shared property like java.toolchain.languageVersion.
    // Verify the installed JDK with `java -version`; if the installed JDK is older, adjust this value or install a matching JDK.
    options.release = 21
}

dependencies {
    implementation("org.jspecify:jspecify:1.0.0")
    errorprone("com.google.errorprone:error_prone_core:2.42.0")
    errorprone("com.uber.nullaway:nullaway:0.12.12")
}
```

## Add @NullMarked to package-info.java files
For each source package directory that contains at least one `.java` file under the project's `src/main/java` tree (exclude generated sources and `src/test/java`), ensure a `package-info.java` exists and add the `@NullMarked` annotation exactly as shown:

```java
@org.jspecify.annotations.NullMarked
package com.mycompnay.myproject;
```

If `package-info.java` already exists, insert `@org.jspecify.annotations.NullMarked` immediately above the `package` declaration as the first non-comment, non-blank line. Preserve all other existing imports, comments, annotations, and package declaration lines without removing or reordering them.
For multi-module projects, repeat this package-info change in each module's `src/main/java` tree.

## Verify jSpecify support
If Python 3 is available, run `python3 scripts/verify_nullmarked.py` from the repository root. If Python 3 is not installed, report: `Python 3 required to run scripts/verify_nullmarked.py; install python3 or run an alternative verifier.`
