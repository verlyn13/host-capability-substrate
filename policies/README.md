# policies/ (this repo) — test fixture only

**Canonical live HCS policy lives at:**
`~/Organizations/jefahnierocks/system-config/policies/host-capability-substrate/`

This repo's `policies/generated-snapshot/` directory is a **test fixture**, not a source of truth. It is populated by CI from the canonical system-config policy at a specific commit hash, and is used only to run kernel + adapter tests against a stable policy shape.

## Why

Charter invariant 10 (ADR 0011): HCS is public source with a private deployment boundary. Live policy carries authority over this host; the public repo does not. Live policy changes are reviewed under the system-config governance process, not here.

## What lives where

- **Tier YAML** (`tiers.yaml`): `system-config/policies/host-capability-substrate/tiers.yaml`
- **OPA Rego** (future, if triggered per D-008): `system-config/policies/host-capability-substrate/*.rego`
- **Gateway contract**: `system-config/policies/host-capability-substrate/gateway.contract.md`
- **Audit schema**: `system-config/policies/host-capability-substrate/storage.sql`
- **In-repo snapshot** (this dir, CI-populated): `policies/generated-snapshot/`

## Contributing

Do **not** edit files here directly. Instead:

1. Propose changes to `system-config/policies/host-capability-substrate/`.
2. `hcs-policy-reviewer` subagent objections must be filed (per implementation charter v1.1.0+ authoring rules).
3. Human approval in the system-config PR.
4. CI regenerates `policies/generated-snapshot/` in this repo and commits the updated snapshot.

## References

- Charter: `docs/host-capability-substrate/implementation-charter.md` (invariants 5, 10)
- ADR 0006 (policy source location)
- ADR 0011 (public/private boundary)
- `DECISIONS.md` D-004, D-018
