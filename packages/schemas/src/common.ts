import { z } from 'zod';

export const schemaVersionSchema = z
  .literal('0.1.0')
  .describe('Entity schema version for the first Phase 1 Ring 0 schema slice.');

export const entityIdSchema = z
  .string()
  .min(1)
  .regex(/^[A-Za-z0-9][A-Za-z0-9._:-]*$/)
  .describe('Stable local entity identifier. It is not a secret value.');

export const isoDateTimeSchema = z
  .string()
  .datetime({ offset: true })
  .describe('RFC 3339 timestamp with an explicit UTC offset.');

export const evidenceAuthoritySchema = z
  .enum([
    'project-local',
    'workspace-local',
    'user-global',
    'system',
    'derived',
    'sandbox-observation',
    'host-observation',
    'vendor-doc',
    'installed-runtime',
    'human-observed',
  ])
  .describe('Authority plane for a fact or observation.');

export const evidenceConfidenceSchema = z
  .enum(['authoritative', 'high', 'best-effort', 'stale', 'unknown'])
  .describe('Confidence assigned to an observation by the producer.');

export const evidenceRefSchema = z
  .object({
    evidence_id: entityIdSchema.describe('Reference to an Evidence record or fixture.'),
    source: z.string().min(1).describe('Human-readable source name or artifact path.'),
    observed_at: isoDateTimeSchema,
    valid_until: isoDateTimeSchema.nullable().optional(),
    authority: evidenceAuthoritySchema,
    parser_version: z.string().min(1).optional(),
    confidence: evidenceConfidenceSchema,
  })
  .strict()
  .describe(
    'Lightweight reference or embedded provenance preview for an Evidence record. Not a substitute for the full Evidence entity.',
  );

export const observationStatusSchema = z
  .enum(['observed_present', 'observed_absent', 'pending', 'unknown', 'not_applicable'])
  .describe('Status for a per-surface capability or inheritance observation.');

export const envVariableNameSchema = z
  .string()
  .min(1)
  .regex(/^[A-Za-z_][A-Za-z0-9_]*$/)
  .describe('Environment variable name only. The schema intentionally has no value field.');

export const sha256DigestSchema = z
  .string()
  .regex(/^sha256:[a-f0-9]{64}$/)
  .describe('SHA-256 digest with algorithm prefix. It is not reversible secret material.');
