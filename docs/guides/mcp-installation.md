# MCP Server Installation Guide

This document contains the configuration for installing MCP servers used in this project.

## Required MCP Servers

This project uses two MCP servers:

1. **Supabase MCP** - Database operations and migrations
2. **Playwright MCP** - Browser automation for testing

---

## 1. Supabase MCP Server

The Supabase MCP server provides database operations and migrations for the Foss SA luminaires database.

### Project Details

- **Project Ref**: `hyppizgiozyyyelwdius`
- **Database**: Foss SA lighting products (14,889+ products)
- **Package**: `@supabase/mcp-server-supabase@latest`

### Installation Options

#### Option 1: Using CLI Command (Recommended)

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

#### Option 2: Using JSON Configuration

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

#### Option 3: Manual Configuration

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

### Available Tools

Once installed, the Supabase MCP provides these tools:

- **Database Operations**: Execute SQL queries, manage schemas
- **Migrations**: Apply and manage database migrations
- **Table Management**: List tables, view structures
- **Logs**: Access project logs for debugging
- **Advisors**: Security and performance recommendations

---

## 2. Playwright MCP Server

The Playwright MCP server provides browser automation capabilities for testing the search UI.

### Package Details

- **Package**: `@playwright/mcp@latest`
- **Purpose**: Browser automation and testing
- **Use Case**: Testing search interface, filter interactions, UI validation

### Installation Options

#### Option 1: Using CLI Command (Recommended)

```bash
claude mcp add --transport stdio playwright -- npx @playwright/mcp@latest
```

**Breakdown:**
- `--transport stdio` - Uses stdio transport
- `playwright` - Name of the MCP server
- `--` - Separates options from the command
- `npx @playwright/mcp@latest` - Runs the Playwright MCP package

---

#### Option 2: Using JSON Configuration

```bash
claude mcp add-json playwright '{"type":"stdio","command":"npx","args":["@playwright/mcp@latest"],"env":{}}'
```

---

#### Option 3: Manual Configuration

Add this to your `~/.claude.json` file:

```json
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "@playwright/mcp@latest"
      ],
      "env": {}
    }
  }
}
```

After editing, restart Claude Code to activate the MCP server.

---

### Available Tools

Once installed, the Playwright MCP provides these tools:

- **Browser Control**: Navigate, click, type, take screenshots
- **Page Snapshots**: Capture accessibility tree for UI analysis
- **Form Filling**: Automate form interactions
- **JavaScript Execution**: Run custom scripts in browser context
- **Network Monitoring**: Track requests and responses
- **Console Logs**: Access browser console output

---

## Verification

After installing both MCP servers, verify they are configured:

```bash
claude mcp list
```

You should see both `supabase` and `playwright` in the list of configured MCP servers.

---

## Related Documentation

- [Supabase MCP Server](https://github.com/supabase/mcp-server-supabase)
- [Playwright MCP Server](https://github.com/microsoft/playwright-mcp)
- [QUICKSTART.md](./QUICKSTART.md) - Implementation guide for this search schema
- [INDEX.md](./INDEX.md) - Repository overview

---

## Quick Install (Both Servers)

Install both MCP servers in one go:

```bash
# Install Supabase MCP
claude mcp add --transport stdio supabase \
  --env SUPABASE_ACCESS_TOKEN=sbp_d2b8856a660bf7b0a019a45a6d6a36b6248a0c17 \
  -- npx -y @supabase/mcp-server-supabase@latest \
  --project-ref=hyppizgiozyyyelwdius

# Install Playwright MCP
claude mcp add --transport stdio playwright -- npx @playwright/mcp@latest

# Verify installation
claude mcp list
```

---

**Last Updated**: 2025-01-17
**Database**: Foss SA Luminaires (hyppizgiozyyyelwdius)
**MCP Servers**: Supabase + Playwright
