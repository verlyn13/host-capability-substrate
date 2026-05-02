import { z } from 'zod';
import { entityIdSchema, evidenceRefSchema, schemaVersionSchema } from '../common.ts';

export const boundaryDimensionSchema = z
  .enum([
    'bundle_identity',
    'check_source',
    'containment_class',
    'credential_routing',
    'egress_observed',
    'egress_policy',
    'filesystem_authority',
    'launch_context',
    'mcp_authorization',
    'origin_access_validation',
    'path_coverage',
    'runner_isolation',
    'sandbox',
    'tcc',
    'volume_authority',
    'worktree_ownership',
  ])
  .describe(
    'Singular boundary dimension from ADR 0022. Registered values mirror docs/host-capability-substrate/ontology-registry.md.',
  );

export const boundaryObservationStateSchema = z
  .enum(['proven', 'denied', 'pending', 'stale', 'contradictory', 'inapplicable', 'unknown'])
  .describe(
    'Seven-state boundary vocabulary from ADR 0022. unknown is not false; missing or unobservable evidence is distinct from denied.',
  );

export const boundaryDiscrepancyClassSchema = z
  .enum([
    'observed_matches_expected',
    'observed_differs_from_expected',
    'expected_unobservable',
    'observed_without_expected',
    'expected_without_observed',
    'unknown',
  ])
  .describe(
    'Optional discrepancy summary between observed_payload and expected_payload. Initial set; ontology-registry workflow may extend it.',
  );

export const boundaryObservationSchema = z
  .object({
    schema_version: schemaVersionSchema,
    evidence_schema_version: schemaVersionSchema,
    payload_schema_version: z.string().min(1).optional(),
    boundary_observation_id: entityIdSchema,
    surface_id: entityIdSchema.optional(),
    execution_context_id: entityIdSchema.optional(),
    workspace_id: entityIdSchema.optional(),
    credential_source_id: entityIdSchema.optional(),
    tool_or_provider_ref: entityIdSchema.optional(),
    boundary_dimension: boundaryDimensionSchema,
    observed_payload: z.json(),
    expected_payload: z.json().optional(),
    observation_state: boundaryObservationStateSchema,
    discrepancy_class: boundaryDiscrepancyClassSchema.optional(),
    evidence_refs: z.array(evidenceRefSchema).min(1),
  })
  .strict()
  .refine(
    (value) =>
      Boolean(
        value.surface_id ||
          value.execution_context_id ||
          value.workspace_id ||
          value.credential_source_id ||
          value.tool_or_provider_ref,
      ),
    {
      message:
        'BoundaryObservation requires at least one target reference: surface_id, execution_context_id, workspace_id, credential_source_id, or tool_or_provider_ref.',
      path: ['boundary_observation_id'],
    },
  )
  .describe('Ring 0 BoundaryObservation envelope from ADR 0022.');

export type BoundaryObservation = z.infer<typeof boundaryObservationSchema>;
export type BoundaryDimension = z.infer<typeof boundaryDimensionSchema>;
export type BoundaryObservationState = z.infer<typeof boundaryObservationStateSchema>;
export type BoundaryDiscrepancyClass = z.infer<typeof boundaryDiscrepancyClassSchema>;
