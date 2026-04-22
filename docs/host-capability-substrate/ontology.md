---
title: HCS Ontology
category: reference
component: host_capability_substrate
status: stub
version: 0.1.0
last_updated: 2026-04-22
tags: [ontology, entities, schemas]
priority: high
---

# HCS Ontology

Authoritative human-facing reference for the 20 core HCS entities. Populated in Phase 1 Thread D (schema work). At Phase 0a this is a stub pointing to the research plan's §2 for sketches and §Appendix A for shape detail.

Canonical research plan sketch: `~/Organizations/jefahnierocks/system-config/docs/host-capability-substrate-research-plan.md` §2 (Ontology) and §Appendix A.

## Entities (20 core)

```
HostProfile          canonical host identity + stable facts
WorkspaceContext     project/workspace identity (workspace.toml-derived)
Principal            a human or automated actor with an identity
AgentClient          connected MCP/A2A/hook client with version + identity
Session              one agent-client connection with declared/measured context
ToolProvider         a source of tools: mise, brew, system, project-local
ToolInstallation     a specific instance of a tool on this host
ResolvedTool         the authoritative answer for "what tool X in this context"
Capability           a declared kernel operation (e.g., service.activate)
OperationShape       semantic operation proposal with target + mutation scope
CommandShape         argv vector + env profile + execution lane (rendered from Operation)
Evidence             a fact with provenance, freshness, authority, confidence
PolicyRule           a tier/destructive-pattern/approval rule (YAML or Rego)
Decision             gateway output: allowed | requires_approval | denied
ApprovalGrant        scoped, expiring, replay-resistant authorization
Run                  one execution of an approved operation through the broker
Artifact             a run's structured output (diff, log chunks, exit code, signed summary)
Lease                exclusive or shared resource lock
Lock                 coarser mutex (e.g., "package-manager global")
SecretReference      op:// URI, never the value
ResourceBudget       per-session CPU/memory/network/sandbox-concurrency allocation
```

Each entity carries a `schema_version`. Entity schema versions are independent of adapter tool-name versions (MCP tool names follow `system.{namespace}.{verb}.v{N}` in adapter surfaces).

## Provenance on every fact

Every `Evidence` record:

```json
{
  "value": "...",
  "source": "...",
  "observed_at": "...",
  "valid_until": "...",
  "authority": "project-local | workspace-local | user-global | system | derived | sandbox-observation",
  "cwd": "...",
  "parser_version": "...",
  "confidence": "authoritative | high | best-effort | stale | unknown",
  "host_id": "...",
  "session_id": "..."
}
```

## Populated by

- `hcs-ontology-reviewer` subagent catches schema drift
- `hcs-schema-change` skill enforces "schema + docs + JSON Schema + tests move together"
- Phase 1 Thread D delivers Zod schemas + JSON Schema + full entity docs

## References

- Research plan §2, §Appendix A
- Charter invariant 5 (secrets as references), 8 (sandbox authority downgrade), 9 (skills location)

## Change log

| Version | Date | Change |
|---------|------|--------|
| 0.1.0 | 2026-04-22 | Initial stub. Lists 20 entities; points to research plan for shape details. |
