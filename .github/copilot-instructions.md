## GitHub Operations

When performing any GitHub operations (creating repos, pushing code, managing issues, pull requests, branches, or files on GitHub):

- **Always use the GitHub MCP server** configured in `.vscode/mcp.json`. The PAT is stored there — do not ask the user for credentials or suggest `gh auth login`.
- The MCP server is available at `https://api.githubcopilot.com/mcp/` and is pre-authenticated.
- The GitHub account is **Fencer4Life** and the primary repository is **spws-automated-ranklist** (private).
- Prefer MCP tools (`mcp_github_*`) over terminal `git` or `gh` CLI commands for all GitHub API interactions.
- For local git operations (commit, status, diff) use the terminal as normal.
- When pushing, use the token from `.vscode/mcp.json` embedded in the remote URL rather than interactive credential prompts.
