# Agent Instructions

This repository contains agent skills and Claude Code plugins for working with Java applications. 
It contains opinionated development guidelines, best practices, and automation patterns that can be installed into projects.

## Installation Methods

### Method 1: Claude Code Plugin Installation

Install plugins using Claude Code CLI. First add the marketplace, then install plugins:

```bash
# Add the agent-skills marketplace
claude plugin marketplace add sivaprasadreddy/sivalabs-agent-skills

# Install plugins
claude plugin install java-dev@sivalabs-agent-skills
```

Installation scopes (use `--scope` flag):
- `user` (default): Available across all projects
- `project`: Shared with team via `.claude/settings.json`
- `local`: Project-specific, gitignored

### Method 2: Individual Skill Installation

Install individual skills using `npx skills add`:

```shell
# Via npx
npx skills add https://github.com/sivaprasadreddy/sivalabs-agent-skills
npx skills add https://github.com/sivaprasadreddy/sivalabs-agent-skills --skill spring-boot
```

## Skill Format

Each skill directory contains:
- `SKILL.md` - Main skill definition with YAML frontmatter (`name`, `description`)
- Optional `assets/`, `references/`, or `resources/` directories

### SKILL.md Frontmatter

```yaml
---
name: skill-name
description: Brief description of when to use this skill.
---
```

## When to Use Each Plugin

### java-dev
Use when:
- Building Java and Spring Boot applications
- Building Spring Boot REST APIs
- Building Modular Monoliths using Spring Modulith
