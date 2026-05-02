import { describe, expect, it } from 'vitest';
import {
  credentialSourceSchema,
  envProvenanceSchema,
  evidenceSchema,
  executionContextSchema,
  startupPhaseSchema,
} from '../src/index.ts';

const evidenceRef = {
  evidence_id: 'evidence:p06-host-telemetry',
  source:
    'docs/host-capability-substrate/research/shell-env/2026-04-28-P06-host-telemetry-rerun.md',
  observed_at: '2026-04-28T00:00:00Z',
  authority: 'host-observation',
  confidence: 'high',
} as const;

describe('Phase 1 Ring 0 schemas', () => {
  it('validates StartupPhase order against the ADR 0016 sequence', () => {
    expect(
      startupPhaseSchema.parse({
        schema_version: '0.1.0',
        startup_phase_id: 'phase:tool-call',
        phase: 'tool_call_subprocess',
        order: 14,
        description: 'Actual tool subprocess execution.',
        evidence_refs: [evidenceRef],
      }).phase,
    ).toBe('tool_call_subprocess');

    expect(
      startupPhaseSchema.safeParse({
        schema_version: '0.1.0',
        startup_phase_id: 'phase:bad-order',
        phase: 'mcp_server_init',
        order: 11,
        description: 'Incorrect ordering must not parse.',
        evidence_refs: [evidenceRef],
      }).success,
    ).toBe(false);
  });

  it('keeps Codex app evidence separate from CLI shell evidence', () => {
    const context = executionContextSchema.parse({
      schema_version: '0.1.0',
      execution_context_id: 'ctx:codex-app-sandboxed:p13',
      surface: 'codex_app_sandboxed',
      kind: 'gui_app',
      phase: 'gui_app_exec',
      shell: {
        carrier: 'app_rpc',
        shell_path: null,
        argv_flags: [],
        login_observed: 'not_applicable',
        interactive_observed: 'not_applicable',
        startup_files_observed: [],
        marker_env_visible: 'observed_absent',
      },
      sandbox: {
        profile: 'seatbelt',
        filesystem: 'pending',
        network: 'pending',
        keychain: 'pending',
      },
      env_inheritance: {
        mode: 'launchd_user_session_only',
        terminal_shell_inherited: 'observed_absent',
      },
      open_questions: ['app-internal Keychain/filesystem/network rows remain pending'],
      evidence_refs: [evidenceRef],
    });

    expect(context.surface).toBe('codex_app_sandboxed');
    expect(context.env_inheritance.terminal_shell_inherited).toBe('observed_absent');
  });

  it('records env provenance without accepting raw env values', () => {
    const parsed = envProvenanceSchema.parse({
      schema_version: '0.1.0',
      env_provenance_id: 'env:codex-cli:path',
      execution_context_id: 'ctx:codex-cli:tool-call',
      variable_name: 'PATH',
      source_kind: 'codex_policy',
      materialization: 'runtime_applied',
      observation_mode: 'classified',
      sensitivity: 'non_secret',
      operator_filter: 'include_only',
      evidence_refs: [evidenceRef],
    });

    expect(parsed.variable_name).toBe('PATH');
    expect(
      envProvenanceSchema.safeParse({
        ...parsed,
        value: '/usr/bin:/bin',
      }).success,
    ).toBe(false);
  });

  it('records credential sources as references, not secret material', () => {
    const credential = credentialSourceSchema.parse({
      schema_version: '0.1.0',
      credential_source_id: 'cred:claude-setup-token',
      source_type: 'long_lived_setup_token',
      owning_surface: 'claude_code_cli',
      storage_plane: 'provider_control_plane',
      durability: 'long_lived',
      scope: {
        provider: 'anthropic',
        audience: 'claude-code-cli',
        capabilities: ['inference'],
      },
      secret_ref: 'hcs://secret-reference/claude-setup-token',
      rotation: {
        expected: true,
      },
      health: {
        status: 'pending_verification',
      },
      evidence_refs: [evidenceRef],
    });

    expect(credential.source_type).toBe('long_lived_setup_token');
    expect(
      credentialSourceSchema.safeParse({
        ...credential,
        secret_material: 'not-allowed',
      }).success,
    ).toBe(false);
  });

  it('validates Evidence as the shared provenance and freshness base entity', () => {
    const evidence = evidenceSchema.parse({
      schema_version: '0.1.0',
      evidence_id: 'evidence:codex-cli-tool-shell',
      evidence_kind: 'observation',
      subject_refs: [
        {
          subject_kind: 'execution_context',
          subject_id: 'ctx:codex-cli:tool-call',
          relation: 'observed_context',
        },
      ],
      source:
        'docs/host-capability-substrate/research/shell-env/2026-04-28-P06-host-telemetry-rerun.md',
      source_ref: 'host-telemetry:p06',
      observed_at: '2026-04-28T00:00:00Z',
      valid_until: null,
      authority: 'host-observation',
      confidence: 'high',
      parser_version: 'human-review:v1',
      execution_context_id: 'ctx:codex-cli:tool-call',
      payload_schema_version: 'p06-host-telemetry:v1',
      payload: {
        shell_argv: ['/bin/zsh', '-c', '<redacted>'],
      },
      redaction_mode: 'redacted',
    });

    expect(evidence.evidence_kind).toBe('observation');
    expect(evidence.subject_refs[0]?.subject_kind).toBe('execution_context');
  });

  it('keeps sandbox-observation Evidence bound to the sandbox context and trace', () => {
    expect(
      evidenceSchema.safeParse({
        schema_version: '0.1.0',
        evidence_id: 'evidence:sandbox-missing-context',
        evidence_kind: 'observation',
        subject_refs: [
          {
            subject_kind: 'execution_context',
            subject_id: 'ctx:codex-cli:tool-call',
          },
        ],
        source: 'packages/fixtures/provenance-snapshot-2026-04-30.json',
        observed_at: '2026-04-30T00:00:00Z',
        valid_until: null,
        authority: 'sandbox-observation',
        confidence: 'best-effort',
        parser_version: 'fixture:v1',
      }).success,
    ).toBe(false);

    expect(
      evidenceSchema.parse({
        schema_version: '0.1.0',
        evidence_id: 'evidence:sandbox-bound',
        evidence_kind: 'fixture',
        subject_refs: [
          {
            subject_kind: 'execution_context',
            subject_id: 'ctx:codex-cli:tool-call',
          },
        ],
        source: 'packages/fixtures/provenance-snapshot-2026-04-30.json',
        observed_at: '2026-04-30T00:00:00Z',
        valid_until: null,
        authority: 'sandbox-observation',
        confidence: 'best-effort',
        parser_version: 'fixture:v1',
        execution_context_id: 'ctx:codex-cli:tool-call',
        source_ref: 'fixture:provenance-snapshot-2026-04-30',
        redaction_mode: 'classified',
      }).authority,
    ).toBe('sandbox-observation');
  });
});
