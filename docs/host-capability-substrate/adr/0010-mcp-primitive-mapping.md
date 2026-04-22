---
adr_number: 0010
title: MCP primitive mapping — tools for calls, resources for context, prompts for workflows
status: accepted
date: 2026-04-22
charter_version: 1.1.0
tags: [mcp, primitives, tools, resources, prompts]
---

# ADR 0010: MCP primitive mapping

## Context

MCP 2025-11-25 exposes three primitives: tools (model-controlled executable functions), resources (application-controlled context), prompts (user-controlled templates). Not everything should be a tool.

## Decision

- **Tools** — live introspection, policy evaluation, preview, future execution:
  - `system.host.profile.v1`, `system.session.current.v1`, `system.tool.resolve.v1`, `system.tool.help.v1`, `system.policy.classify_operation.v1`, `system.gateway.propose.v1`, `system.audit.recent.v1`, `system.dashboard.summary.v1`
- **Resources** — cached snapshots and read-only context:
  - cached host profile snapshots
  - cached help/man pages
  - policy documents
  - audit summaries
  - tool-resolution evidence
  - dashboard deep links
  - capability manifests
- **Prompts** — human-invoked workflows:
  - "Diagnose Homebrew state"
  - "Explain why this command was denied"
  - "Prepare a safe launchd migration plan"

## Consequences

### Accepts

- Some data is both tool output and resource (dual-exposed).
- Surface grows; we use namespaces under 10 functions each to remain `tool_search`-friendly on GPT-5.4.

### Rejects

- Everything as tools (wastes context; misses resource/prompt affordances).

### Future amendments

- MCP Apps UI embeds may later wrap resources; track per D-012.

## References

### Internal

- Research plan §7 (primitives mapping table), §22.6/§22.7 (Claude/Codex setup)
- Decision ledger: D-012
- Boundary decision §21.9

### External

- [MCP Server overview](https://modelcontextprotocol.io/specification/2025-11-25/server)
- [MCP Tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
- [GPT-5.4 tool_search](https://developers.openai.com/api/docs/guides/tools-tool-search)
