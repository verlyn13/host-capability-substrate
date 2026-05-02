import { z } from 'zod';
import {
  entityIdSchema,
  evidenceAuthoritySchema,
  evidenceConfidenceSchema,
  isoDateTimeSchema,
  schemaVersionSchema,
} from '../common.ts';

export const evidenceKindSchema = z
  .enum(['observation', 'receipt', 'derived', 'human_decision', 'fixture'])
  .describe('Evidence record family from ADR 0023.');

export const evidenceSubjectKindSchema = z
  .enum([
    'host',
    'workspace',
    'principal',
    'agent_client',
    'session',
    'tool_provider',
    'tool_installation',
    'resolved_tool',
    'capability',
    'operation_shape',
    'command_shape',
    'evidence',
    'policy_rule',
    'decision',
    'approval_grant',
    'run',
    'artifact',
    'lease',
    'lock',
    'secret_reference',
    'resource_budget',
    'execution_context',
    'credential_source',
    'startup_phase',
    'provider_object',
    'external_control_plane',
    'git_repository',
    'git_ref',
    'github_check',
    'filesystem_path',
    'process',
    'unknown',
  ])
  .describe('Kind of subject the evidence is about.');

export const evidenceSubjectRefSchema = z
  .object({
    subject_kind: evidenceSubjectKindSchema,
    subject_id: z.string().min(1),
    relation: z.string().min(1).optional(),
  })
  .strict()
  .describe('Reference to the subject described by an Evidence record.');

export const evidenceRedactionModeSchema = z
  .enum(['none', 'redacted', 'classified', 'hash_only', 'reference_only', 'mixed'])
  .describe('How sensitive payload material was handled before persistence.');

const evidenceBaseSchema = z
  .object({
    schema_version: schemaVersionSchema,
    evidence_id: entityIdSchema,
    evidence_kind: evidenceKindSchema,
    subject_refs: z.array(evidenceSubjectRefSchema).min(1),
    source: z.string().min(1),
    source_ref: z.string().min(1).optional(),
    observed_at: isoDateTimeSchema,
    valid_until: isoDateTimeSchema.nullable(),
    authority: evidenceAuthoritySchema,
    confidence: evidenceConfidenceSchema,
    parser_version: z.string().min(1),
    producer: z.string().min(1).optional(),
    host_id: entityIdSchema.optional(),
    workspace_id: entityIdSchema.optional(),
    execution_context_id: entityIdSchema.optional(),
    session_id: entityIdSchema.optional(),
    run_id: entityIdSchema.optional(),
    payload_schema_version: z.string().min(1).optional(),
    payload: z.json().optional(),
    redaction_mode: evidenceRedactionModeSchema.optional(),
  })
  .strict();

const sandboxEvidenceBaseSchema = evidenceBaseSchema.extend({
  authority: z.literal('sandbox-observation'),
  execution_context_id: entityIdSchema,
});

export const evidenceSchema = z
  .union([
    evidenceBaseSchema.extend({
      authority: evidenceAuthoritySchema.exclude(['sandbox-observation']),
    }),
    sandboxEvidenceBaseSchema.extend({
      source_ref: z.string().min(1),
    }),
    sandboxEvidenceBaseSchema.extend({
      session_id: entityIdSchema,
    }),
    sandboxEvidenceBaseSchema.extend({
      run_id: entityIdSchema,
    }),
  ])
  .describe('Ring 0 Evidence base entity from ADR 0023.');

export type Evidence = z.infer<typeof evidenceSchema>;
export type EvidenceKind = z.infer<typeof evidenceKindSchema>;
export type EvidenceSubjectKind = z.infer<typeof evidenceSubjectKindSchema>;
