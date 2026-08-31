# Project-Specific Agent Rules for pure_regex

## Release & Versioning Policy
- **Clarify Release Mode**: Whenever instructed to release (e.g. "release", "make a release", "cut a release"), ALWAYS ask the user explicitly whether this is a **dev release** (e.g. `X.Y.Z.devN`) or a **final/stable release** (e.g. `X.Y.Z`), and confirm the exact version number before proceeding.

## AI Agent Toolkit Integration
- **Toolkit Integration**: Shared Prolog standards, skills, and guidelines are loaded globally via the assistant configuration (e.g. `~/.gemini/config/skills.json` or `~/.agents/skills`) rather than embedded Git submodules.
- **Local Project Skills**: Repository-specific skills are maintained directly under `.agents/skills/`.
