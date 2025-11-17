# MCP Server Installation Guide

This document contains the configuration for installing the Supabase MCP server used in this project.

## Supabase MCP Server

The Supabase MCP server provides database operations and migrations for the Foss SA luminaires database.

### Project Details

- **Project Ref**: `hyppizgiozyyyelwdius`
- **Database**: Foss SA lighting products (14,889+ products)
- **Package**: `@supabase/mcp-server-supabase@latest`

---

## Installation Options

### Option 1: Using CLI Command (Recommended)

```bash
claude mcp add --transport stdio supabase \
  --env SUPABASE_ACCESS_TOKEN=sbp_d2b8856a660bf7b0a019a45a6d6a36b6248a0c17 \
  -- npx -y @supabase/mcp-server-supabase@latest \
  --project-ref=hyppizgiozyyyelwdius
```

**Breakdown:**
- `--transport stdio` - Uses stdio transport (standard input/output)
- `supabase` - Name of the MCP server
- `--env SUPABASE_ACCESS_TOKEN=...` - Sets the environment variable
- `--` - Separates options from the command
- `npx -y @supabase/mcp-server-supabase@latest` - Runs the MCP server package
- `--project-ref=hyppizgiozyyyelwdius` - Specifies the Supabase project

---

### Option 2: Using JSON Configuration

```bash
claude mcp add-json supabase '{
  "type": "stdio",
  "command": "npx",
  "args": [
    "-y",
    "@supabase/mcp-server-supabase@latest",
    "--project-ref=hyppizgiozyyyelwdius"
  ],
  "env": {
    "SUPABASE_ACCESS_TOKEN": "sbp_d2b8856a660bf7b0a019a45a6d6a36b6248a0c17"
  }
}'
```

**Note**: Make sure to use single quotes around the JSON string to avoid shell interpretation issues.

---

### Option 3: Manual Configuration

Add this to your `~/.claude.json` file:

```json
{
  "mcpServers": {
    "supabase": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@supabase/mcp-server-supabase@latest",
        "--project-ref=hyppizgiozyyyelwdius"
      ],
      "env": {
        "SUPABASE_ACCESS_TOKEN": "sbp_d2b8856a660bf7b0a019a45a6d6a36b6248a0c17"
      }
    }
  }
}
```

After editing, restart Claude Code to activate the MCP server.

---

## Verification

After installation, verify the MCP server is configured:

```bash
claude mcp list
```

You should see `supabase` in the list of configured MCP servers.

---

## Available Tools

Once installed, the Supabase MCP provides these tools:

- **Database Operations**: Execute SQL queries, manage schemas
- **Migrations**: Apply and manage database migrations
- **Table Management**: List tables, view structures
- **Logs**: Access project logs for debugging
- **Advisors**: Security and performance recommendations

---

## Related Documentation

- [Supabase MCP Server](https://github.com/supabase/mcp-server-supabase)
- [QUICKSTART.md](./QUICKSTART.md) - Implementation guide for this search schema
- [INDEX.md](./INDEX.md) - Repository overview

---

**Last Updated**: 2025-01-17
**Database**: Foss SA Luminaires (hyppizgiozyyyelwdius)
**MCP Package**: @supabase/mcp-server-supabase@latest
