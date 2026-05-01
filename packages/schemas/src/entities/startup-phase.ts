import { z } from 'zod';
import { entityIdSchema, evidenceRefSchema, schemaVersionSchema } from '../common.ts';

export const startupPhaseNames = [
  'boot',
  'launchd_user_session',
  'gui_app_exec',
  'terminal_emulator_launch',
  'shell_login_init',
  'shell_interactive_init',
  'direnv_chpwd',
  'mise_activate',
  'agent_launch',
  'agent_env_policy_apply',
  'agent_session_hook',
  'mcp_server_init',
  'subagent_spawn',
  'tool_call_subprocess',
] as const;

export const startupPhaseNameSchema = z
  .enum(startupPhaseNames)
  .describe('Ordered startup phase from ADR 0016 shell/environment synthesis.');

export type StartupPhaseName = z.infer<typeof startupPhaseNameSchema>;

export const startupPhaseOrder = {
  boot: 1,
  launchd_user_session: 2,
  gui_app_exec: 3,
  terminal_emulator_launch: 4,
  shell_login_init: 5,
  shell_interactive_init: 6,
  direnv_chpwd: 7,
  mise_activate: 8,
  agent_launch: 9,
  agent_env_policy_apply: 10,
  agent_session_hook: 11,
  mcp_server_init: 12,
  subagent_spawn: 13,
  tool_call_subprocess: 14,
} as const satisfies Record<StartupPhaseName, number>;

export const startupPhaseSchema = z
  .object({
    schema_version: schemaVersionSchema,
    startup_phase_id: entityIdSchema,
    phase: startupPhaseNameSchema,
    order: z.number().int().min(1).max(14),
    description: z.string().min(1),
    evidence_refs: z.array(evidenceRefSchema).min(1),
  })
  .strict()
  .superRefine((value, ctx) => {
    if (startupPhaseOrder[value.phase] !== value.order) {
      ctx.addIssue({
        code: 'custom',
        path: ['order'],
        message: `order must match phase ${value.phase}`,
      });
    }
  })
  .describe('Temporal ordering entity for environment and credential availability.');

export type StartupPhase = z.infer<typeof startupPhaseSchema>;
