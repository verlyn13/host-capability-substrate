import { describe, expect, it } from 'vitest';
import { boundaryObservationSchema } from '../src/index.ts';

const evidenceRef = {
  evidence_id: 'evidence:tcc-snapshot-2026-04-29',
  source:
    'docs/host-capability-substrate/research/local/2026-04-29-quality-management-synthesis.md',
  observed_at: '2026-04-29T00:00:00Z',
  authority: 'host-observation',
  confidence: 'high',
} as const;

describe('BoundaryObservation envelope', () => {
  it('parses a TCC observation bound to an execution context', () => {
    const obs = boundaryObservationSchema.parse({
      schema_version: '0.1.0',
      evidence_schema_version: '0.1.0',
      payload_schema_version: 'tcc-grant:v1',
      boundary_observation_id: 'bo:tcc:claude-code-cli:full-disk',
      execution_context_id: 'ctx:claude-code-cli:p06',
      boundary_dimension: 'tcc',
      observed_payload: {
        tcc_service: 'kTCCServiceFullDiskAccess',
        grant_state: 'granted',
      },
      expected_payload: {
        tcc_service: 'kTCCServiceFullDiskAccess',
        grant_state: 'granted',
      },
      observation_state: 'proven',
      discrepancy_class: 'observed_matches_expected',
      evidence_refs: [evidenceRef],
    });

    expect(obs.boundary_dimension).toBe('tcc');
    expect(obs.observation_state).toBe('proven');
    expect(obs.execution_context_id).toBe('ctx:claude-code-cli:p06');
  });

  it('rejects an envelope with no target reference', () => {
    expect(
      boundaryObservationSchema.safeParse({
        schema_version: '0.1.0',
        evidence_schema_version: '0.1.0',
        boundary_observation_id: 'bo:floating',
        boundary_dimension: 'sandbox',
        observed_payload: { profile_name: 'seatbelt' },
        observation_state: 'unknown',
        evidence_refs: [evidenceRef],
      }).success,
    ).toBe(false);
  });

  it('preserves the seven-state vocabulary, including unknown is not denied', () => {
    const obs = boundaryObservationSchema.parse({
      schema_version: '0.1.0',
      evidence_schema_version: '0.1.0',
      boundary_observation_id: 'bo:unknown-sandbox',
      execution_context_id: 'ctx:codex-app-sandboxed:p13',
      boundary_dimension: 'sandbox',
      observed_payload: { profile_name: 'seatbelt' },
      observation_state: 'unknown',
      evidence_refs: [evidenceRef],
    });

    expect(obs.observation_state).toBe('unknown');
  });

  it('refuses ad-hoc boundary_dimension values such as version_drift', () => {
    expect(
      boundaryObservationSchema.safeParse({
        schema_version: '0.1.0',
        evidence_schema_version: '0.1.0',
        boundary_observation_id: 'bo:bad-dimension',
        execution_context_id: 'ctx:claude-code-cli:p06',
        boundary_dimension: 'version_drift',
        observed_payload: {},
        observation_state: 'pending',
        evidence_refs: [evidenceRef],
      }).success,
    ).toBe(false);
  });

  it('accepts a check_source observation bound to a provider object reference', () => {
    const obs = boundaryObservationSchema.parse({
      schema_version: '0.1.0',
      evidence_schema_version: '0.1.0',
      payload_schema_version: 'check-source:v1',
      boundary_observation_id: 'bo:check-source:hcs-verify',
      tool_or_provider_ref: 'gh:check:host-capability-substrate:verify',
      boundary_dimension: 'check_source',
      observed_payload: {
        check_name: 'verify',
        source_app_id: '15368',
        commit_sha: '6a4b497c9e9bfe43c0a05ed52e382b74d3ea39e3',
      },
      observation_state: 'proven',
      evidence_refs: [evidenceRef],
    });

    expect(obs.boundary_dimension).toBe('check_source');
    expect(obs.tool_or_provider_ref).toBe('gh:check:host-capability-substrate:verify');
  });

  it('rejects extra envelope fields that are not in the strict shape', () => {
    expect(
      boundaryObservationSchema.safeParse({
        schema_version: '0.1.0',
        evidence_schema_version: '0.1.0',
        boundary_observation_id: 'bo:strict-test',
        execution_context_id: 'ctx:claude-code-cli:p06',
        boundary_dimension: 'sandbox',
        observed_payload: { profile_name: 'seatbelt' },
        observation_state: 'proven',
        evidence_refs: [evidenceRef],
        unauthorized_field: 'should-be-rejected',
      }).success,
    ).toBe(false);
  });
});
