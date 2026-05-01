import { z } from 'zod';
import {
  entityIdSchema,
  envVariableNameSchema,
  evidenceRefSchema,
  schemaVersionSchema,
  sha256DigestSchema,
} from '../common.ts';

export const envProvenanceSourceKindSchema = z
  .enum([
    'launchd_user_session',
    'launchctl_setenv',
    'launchagent_plist',
    'shell_rc',
    'direnv_envrc',
    'mise_toml_env',
    'devcontainer',
    'codex_policy',
    'claude_env_file',
    'session_start_hook',
    'warp_drive',
    'onepassword_reference',
    'api_key_helper',
    'secretspec',
  ])
  .describe('Source class for an environment variable name or redacted observation.');

export const envMaterializationSchema = z
  .enum(['baked', 'runtime_applied', 'probed'])
  .describe('Devcontainer-derived env timing class adopted by ADR 0016.');

export const envObservationModeSchema = z
  .enum(['name_only', 'existence_only', 'classified', 'hash_only', 'absent', 'not_observed'])
  .describe('Secret-safe observation mode. Raw values are intentionally excluded.');

export const envSensitivitySchema = z
  .enum(['secret_shaped', 'credential_reference', 'non_secret', 'unknown'])
  .describe('Classifier result without exposing the variable value.');

export const envOperatorFilterSchema = z
  .enum([
    'inherit',
    'include_only',
    'exclude',
    'set',
    'overrides',
    'ignore_default_excludes',
    'none',
  ])
  .describe('Operator policy affecting whether the variable reaches a context.');

export const envProvenanceSchema = z
  .object({
    schema_version: schemaVersionSchema,
    env_provenance_id: entityIdSchema,
    execution_context_id: entityIdSchema,
    variable_name: envVariableNameSchema,
    source_kind: envProvenanceSourceKindSchema,
    source_ref: z.string().min(1).optional(),
    materialization: envMaterializationSchema,
    observation_mode: envObservationModeSchema,
    sensitivity: envSensitivitySchema,
    value_hash: sha256DigestSchema.optional(),
    operator_filter: envOperatorFilterSchema.default('none'),
    credential_source_id: entityIdSchema.optional(),
    evidence_refs: z.array(evidenceRefSchema).min(1),
  })
  .strict()
  .describe('Ring 0 env provenance entity. It records names, classifications, and hashes only.');

export type EnvProvenance = z.infer<typeof envProvenanceSchema>;
