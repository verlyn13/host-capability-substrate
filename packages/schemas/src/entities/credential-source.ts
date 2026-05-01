import { z } from 'zod';
import {
  entityIdSchema,
  envVariableNameSchema,
  evidenceRefSchema,
  isoDateTimeSchema,
  schemaVersionSchema,
} from '../common.ts';
import { executionContextSurfaceSchema } from './execution-context.ts';

export const credentialSourceTypeSchema = z
  .enum([
    'macos_keychain',
    'codex_home_file',
    'claude_credentials_file',
    'oauth_device_flow',
    'subscription_oauth',
    'api_key_env',
    'api_key_helper',
    'onepassword',
    'infisical',
    'vault',
    'devenv_secretspec',
    'long_lived_setup_token',
    'service_account',
    'brokered_secret_reference',
  ])
  .describe('Durable credential source class from ADR 0018.');

export const credentialStoragePlaneSchema = z
  .enum([
    'macos_keychain',
    'user_config_file',
    'shell_env',
    'broker',
    'provider_control_plane',
    'external_secret_store',
    'unknown',
  ])
  .describe('Where credential authority is durably stored.');

export const credentialDurabilitySchema = z
  .enum(['process', 'session', 'long_lived', 'rotating', 'one_time_capture', 'unknown'])
  .describe('Expected lifetime class for a credential source.');

export const credentialHealthStatusSchema = z
  .enum(['healthy', 'failing', 'expired', 'pending_verification', 'unknown'])
  .describe('Healthcheck status without exposing credential material.');

export const credentialScopeSchema = z
  .object({
    provider: z.string().min(1),
    audience: z.string().min(1).optional(),
    capabilities: z.array(z.string().min(1)).default([]),
  })
  .strict()
  .describe('Provider scope and audience metadata for a credential source.');

export const credentialRotationSchema = z
  .object({
    expected: z.boolean(),
    last_rotated_at: isoDateTimeSchema.nullable().optional(),
    rotate_by: isoDateTimeSchema.nullable().optional(),
  })
  .strict()
  .describe('Rotation expectation and timestamps for the credential source.');

export const credentialHealthSchema = z
  .object({
    status: credentialHealthStatusSchema,
    checked_at: isoDateTimeSchema.nullable().optional(),
  })
  .strict()
  .describe('Last healthcheck status for a credential source.');

export const credentialSourceSchema = z
  .object({
    schema_version: schemaVersionSchema,
    credential_source_id: entityIdSchema,
    source_type: credentialSourceTypeSchema,
    owning_surface: executionContextSurfaceSchema.optional(),
    storage_plane: credentialStoragePlaneSchema,
    durability: credentialDurabilitySchema,
    scope: credentialScopeSchema,
    secret_ref: z
      .string()
      .min(1)
      .optional()
      .describe('Opaque reference only, such as op:// or hcs://. Never raw secret material.'),
    env_var_name: envVariableNameSchema.optional(),
    expires_at: isoDateTimeSchema.nullable().optional(),
    rotation: credentialRotationSchema,
    health: credentialHealthSchema,
    evidence_refs: z.array(evidenceRefSchema).min(1),
  })
  .strict()
  .describe('Ring 0 credential source entity from ADR 0018.');

export type CredentialSource = z.infer<typeof credentialSourceSchema>;
