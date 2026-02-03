# Spring Boot Skills for AI Coding Agents

A collection of skills/guidelines for building Spring Boot applications.

## Usage

### Claude Code

To use globally copy `spring-boot-skill` directory into `~/.claude/skills/` directory.

To use in a project, copy `spring-boot-skill` directory into `{project_root}/.claude/skills/` directory.

For more info refer https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview

### OpenAI Codex

To use globally copy `spring-boot-skill` directory into `~/.codex/skills/` directory.

To use in a project, copy `spring-boot-skill` directory into `{project_root}/.codex/skills/` directory.

For more info refer https://developers.openai.com/codex/skills/

### Google Gemini CLI

To use globally copy `spring-boot-skill` directory into `~/.gemini/skills/` directory.

To use in a project, copy `spring-boot-skill` directory into `{project_root}/.gemini/skills/` directory.

For more info refer https://geminicli.com/docs/cli/skills/

### Agent Skills with symlinks

Instead of copying the same skills for multiple agents, you can create symlinks to the skills directory as follows:

Copy the skills in `{project_root}/.agents/skills/` directory.

```shell
cd {project_root}
ln -s {project_root}/.agents {project_root}/.claude
ln -s {project_root}/.agents {project_root}/.codex
ln -s {project_root}/.agents {project_root}/.gemini
```

This way, all agents will use the same skills, and any updates to the `.agents/skills` will be reflected for all agents.
