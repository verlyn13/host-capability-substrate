import { z } from 'zod';
import {
  entityIdSchema,
  evidenceRefSchema,
  observationStatusSchema,
  schemaVersionSchema,
} from '../common.ts';
import { startupPhaseNameSchema } from './startup-phase.ts';

export const executionContextSurfaceSchema = z
  .enum([
    'codex_cli',
    'codex_app_sandboxed',
    'codex_ide_ext',
    'claude_code_cli',
    'claude_desktop',
    'claude_code_ide_ext',
    'zed_external_agent',
    'warp_terminal',
    'mcp_server',
    'setup_script',
    'app_integrated_terminal',
    'unknown',
  ])
  .describe('Agent or host surface that owns this execution context.');

export const executionContextKindSchema = z
  .enum([
    'cli',
    'gui_app',
    'ide_extension',
    'terminal',
    'mcp_server',
    'setup_script',
    'subagent',
    'background_worker',
    'unknown',
  ])
  .describe('General execution-context family.');

export const shellCarrierSchema = z
  .enum([
    'none',
    'argv_exec',
    'shell_command',
    'mcp_stdio',
    'mcp_http',
    'app_rpc',
    'ide_task',
    'integrated_terminal',
    'unknown',
  ])
  .describe('Mechanism carrying work into the process.');

export const shellStartupFileSchema = z
  .enum([
    'none',
    'etc_profile',
    'etc_zprofile',
    'etc_zshenv',
    'etc_zshrc',
    'user_profile',
    'user_bash_profile',
    'user_bashrc',
    'user_zprofile',
    'user_zshenv',
    'user_zshrc',
    'direnv_envrc',
    'mise_config',
    'unknown',
  ])
  .describe('Startup file observed or declared for a shell phase.');

export const sandboxProfileSchema = z
  .enum([
    'none',
    'seatbelt',
    'sandbox_exec',
    'workspace_write',
    'read_only',
    'full_access',
    'ide_host',
    'unknown',
  ])
  .describe('Coarse sandbox profile for the execution context.');

export const contextCapabilityStatusSchema = z
  .enum(['observed_allowed', 'observed_denied', 'pending', 'unknown', 'not_applicable'])
  .describe('Capability status for the named execution-context surface.');

export const envInheritanceModeSchema = z
  .enum([
    'none',
    'launchd_user_session_only',
    'process_spawn',
    'codex_shell_environment_policy',
    'claude_settings_env',
    'terminal_shell',
    'direnv_mise',
    'unknown',
  ])
  .describe('Declared or observed environment inheritance mode.');

export const codexShellEnvironmentPolicyModeSchema = z
  .enum(['inherit', 'include_only', 'exclude', 'set', 'overrides', 'ignore_default_excludes'])
  .describe('Codex shell_environment_policy vocabulary adopted by ADR 0016.');

export const executionContextShellSchema = z
  .object({
    carrier: shellCarrierSchema,
    shell_path: z.string().min(1).nullable(),
    argv_flags: z.array(z.string().min(1)).default([]),
    login_observed: observationStatusSchema,
    interactive_observed: observationStatusSchema,
    startup_files_observed: z.array(shellStartupFileSchema).default([]),
    marker_env_visible: observationStatusSchema,
  })
  .strict()
  .describe('Shell carrier facts for a specific surface and startup phase.');

export const executionContextSandboxSchema = z
  .object({
    profile: sandboxProfileSchema,
    filesystem: contextCapabilityStatusSchema,
    network: contextCapabilityStatusSchema,
    keychain: contextCapabilityStatusSchema,
  })
  .strict()
  .describe('Sandbox and app-internal capability matrix for an execution context.');

export const executionContextEnvInheritanceSchema = z
  .object({
    mode: envInheritanceModeSchema,
    terminal_shell_inherited: observationStatusSchema,
    operator_policy: codexShellEnvironmentPolicyModeSchema.nullable().optional(),
  })
  .strict()
  .describe('How environment variables reach, or do not reach, this context.');

export const executionContextSchema = z
  .object({
    schema_version: schemaVersionSchema,
    execution_context_id: entityIdSchema,
    surface: executionContextSurfaceSchema,
    kind: executionContextKindSchema,
    phase: startupPhaseNameSchema,
    host_id: entityIdSchema.optional(),
    workspace_id: entityIdSchema.optional(),
    agent_client_id: entityIdSchema.optional(),
    shell: executionContextShellSchema,
    sandbox: executionContextSandboxSchema,
    env_inheritance: executionContextEnvInheritanceSchema,
    open_questions: z.array(z.string().min(1)).default([]),
    evidence_refs: z.array(evidenceRefSchema).min(1),
  })
  .strict()
  .describe('Ring 0 execution-context entity from ADR 0016 and ADR 0017.');

export type ExecutionContext = z.infer<typeof executionContextSchema>;
export type ExecutionContextSurface = z.infer<typeof executionContextSurfaceSchema>;
