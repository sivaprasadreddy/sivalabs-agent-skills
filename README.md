# SivaLabs Skills for AI Coding Agents

A collection of skills/guidelines for building applications using AI Agents.

## Skills
- [Spring Boot](skills/spring-boot)

## Usage

```shell
$ npx skills add https://github.com/sivaprasadreddy/sivalabs-agent-skills

# Installing specific skill
$ npx skills add https://github.com/sivaprasadreddy/sivalabs-agent-skills --skill spring-boot
```

## Manual Installation
Copy the desired skills (`skills/spring-boot`, etc) at project-level (`project/.claude/skills/spring-boot`) or user-level (`~/.claude/skills/spring-boot`).

- Claude Code: `project/.claude/skills/` or `~/.claude/skills/`
- Codex: `project/.codex/skills/` or `~/.codex/skills/`
- Gemini: `project/.gemini/skills/` or `~/.gemini/skills/`
- Cursor: `project/.cursor/skills/` or `~/.cursor/skills/`

```shell
# Install at project-level for all supporting agents
$ curl -fsSL https://raw.githubusercontent.com/sivaprasadreddy/sivalabs-agent-skills/refs/heads/main/install.sh | bash

# Install at project-level for selected agents
$ curl -fsSL https://raw.githubusercontent.com/sivaprasadreddy/sivalabs-agent-skills/refs/heads/main/install.sh | bash -s -- --agent claude --agent codex

# Install at user-level for all supporting agents
$ curl -fsSL https://raw.githubusercontent.com/sivaprasadreddy/sivalabs-agent-skills/refs/heads/main/install.sh | bash -s -- --user

# Install at user-level for selected agents
$ curl -fsSL https://raw.githubusercontent.com/sivaprasadreddy/sivalabs-agent-skills/refs/heads/main/install.sh | bash -s -- --user --agent claude --agent codex
```

## References
* https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
* https://developers.openai.com/codex/skills/
* https://geminicli.com/docs/cli/skills/
