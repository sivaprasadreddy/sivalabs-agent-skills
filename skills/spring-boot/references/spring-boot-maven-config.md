# Maven Configuration for Spring Boot Project

This guide provides instructions on how to configure a Maven project for a Spring Boot application.

## Key principles

Follow these principles when using the Maven build tool for a Spring Boot application:

- Configure `spotless-maven-plugin` to automatically format the code and verify whether code is formatted correctly or not.
- Configure `jacoco-maven-plugin` to ensure tests are written meeting the desired code coverage level.
- Configure `git-commit-id-maven-plugin` to be able to expose the running code git commit information via Actuator.
- Configure `spring-boot-maven-plugin` to add build info to Actuator /info endpoint and specify default image name while building a Docker image using Paketo Buildpacks.  

## pom.xml configuration

```xml
<properties>
    <spotless.version>3.2.0</spotless.version>
    <palantir-java-format.version>2.85.0</palantir-java-format.version>
    <jacoco-maven-plugin.version>0.8.14</jacoco-maven-plugin.version>
    <jacoco.minimum.coverage>80%</jacoco.minimum.coverage>
    <dockerImageName>{dockerhub_username}/${project.artifactId}</dockerImageName>
</properties>

<build>
    <plugins>
        <plugin>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-maven-plugin</artifactId>
            <configuration>
                <image>
                    <name>${dockerImageName}</name>
                </image>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>build-info</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
        <plugin>
            <groupId>io.github.git-commit-id</groupId>
            <artifactId>git-commit-id-maven-plugin</artifactId>
            <configuration>
                <failOnNoGitDirectory>false</failOnNoGitDirectory>
                <failOnUnableToExtractRepoInfo>false</failOnUnableToExtractRepoInfo>
                <generateGitPropertiesFile>true</generateGitPropertiesFile>
                <includeOnlyProperties>
                    <includeOnlyProperty>^git.branch$</includeOnlyProperty>
                    <includeOnlyProperty>^git.commit.id.abbrev$</includeOnlyProperty>
                    <includeOnlyProperty>^git.commit.user.name$</includeOnlyProperty>
                    <includeOnlyProperty>^git.commit.message.full$</includeOnlyProperty>
                </includeOnlyProperties>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>revision</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
        <plugin>
            <groupId>org.jacoco</groupId>
            <artifactId>jacoco-maven-plugin</artifactId>
            <version>${jacoco-maven-plugin.version}</version>
            <executions>
                <!-- Attach JaCoCo agent -->
                <execution>
                    <goals>
                        <goal>prepare-agent</goal>
                    </goals>
                </execution>
                <!-- Generate report -->
                <execution>
                    <id>report</id>
                    <phase>verify</phase>
                    <goals>
                        <goal>report</goal>
                    </goals>
                </execution>
                <!-- Enforce coverage rule -->
                <execution>
                    <id>check</id>
                    <phase>verify</phase>
                    <goals>
                        <goal>check</goal>
                    </goals>
                    <configuration>
                        <rules>
                            <rule>
                                <element>BUNDLE</element>
                                <limits>
                                    <limit>
                                        <counter>LINE</counter>
                                        <value>COVEREDRATIO</value>
                                        <minimum>${jacoco.minimum.coverage}</minimum>
                                    </limit>
                                </limits>
                            </rule>
                        </rules>
                    </configuration>
                </execution>
            </executions>
        </plugin>
        <plugin>
            <groupId>com.diffplug.spotless</groupId>
            <artifactId>spotless-maven-plugin</artifactId>
            <version>${spotless.version}</version>
            <configuration>
                <java>
                    <importOrder/>
                    <removeUnusedImports/>
                    <formatAnnotations/>
                    <palantirJavaFormat>
                        <version>${palantir-java-format.version}</version>
                    </palantirJavaFormat>
                </java>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>check</goal>
                    </goals>
                    <phase>compile</phase>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```
