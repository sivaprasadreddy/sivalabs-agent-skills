# SivaLabs Skills for AI Coding Agents

A collection of skills/guidelines for building applications using AI Agents.

## Skills
- [Spring Boot](skills/spring-boot)

## Usage

```shell
$ curl -fsSL https://raw.githubusercontent.com/sivaprasadreddy/sivalabs-agent-skills/refs/heads/main/install.sh | bash
```

Install skills at project-level or user-level.

- Claude Code: `project/.claude/skills/` or `~/.claude/skills/`
- Codex: `project/.codex/skills/` or `~/.codex/skills/`
- Gemini: `project/.gemini/skills/` or `~/.gemini/skills/`
- Cursor: `project/.cursor/skills/` or `~/.cursor/skills/`

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

## References
* https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
* https://developers.openai.com/codex/skills/
* https://geminicli.com/docs/cli/skills/
