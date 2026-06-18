# Connecting Kairō to AI agents (MCP)

Kairō ships an **MCP (Model Context Protocol) server** that exposes your on-device
memory to any MCP-speaking AI client — Claude Code, Claude Desktop, or an agent
framework. This is Kairō acting as a **context layer**: instead of competing with
an assistant's built-in memory, Kairō *feeds* it your real history.

The server reads from the same `~/.kairo` store as the web app, so anything you
capture in Kairō is instantly available to your AI tools.

## Tools the server exposes

| Tool | What it does |
|------|--------------|
| `search_memory(query, limit)` | Returns the user's most relevant past memories (ranked) — the "give me context" tool |
| `ask_memory(question)` | Kairō's grounded answer + date citations |
| `add_memory(text)` | Saves a new memory (decision, insight, preference) on-device |
| `recent_memories(limit)` | Recent memories, newest first |
| `memory_stats()` | Totals + per-domain counts |

## Run the server manually (sanity check)

```bash
uv run python -m backend.mcp_server   # speaks MCP over stdio; Ctrl-C to stop
```

Requires Ollama running (for search/ask/add).

## Register with Claude Code

Either run:

```bash
claude mcp add kairo -- uv run --directory "/Users/achyuthnarayan/Desktop/Passion Projects/Kairo" python -m backend.mcp_server
```

…or create a file named `.mcp.json` in the project root with:

```json
{
  "mcpServers": {
    "kairo": {
      "command": "uv",
      "args": [
        "run",
        "--directory",
        "/Users/achyuthnarayan/Desktop/Passion Projects/Kairo",
        "python",
        "-m",
        "backend.mcp_server"
      ]
    }
  }
}
```

Restart Claude Code, then try: *"Search my Kairō memory — what triggers my bloating?"*

## Register with Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` and add the
same `mcpServers` block as above, then restart Claude Desktop. Kairō's tools will
appear in the tools (🔌) menu.

> Note: an AI agent generally cannot register an MCP server into its own config
> for you (it's a self-modification guardrail). Adding the config above is a quick
> manual step you do once.
