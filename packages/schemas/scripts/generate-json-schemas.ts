import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { z } from 'zod';
import {
  credentialSourceSchema,
  envProvenanceSchema,
  executionContextSchema,
  startupPhaseSchema,
} from '../src/index.ts';

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const generatedDir = resolve(packageRoot, 'generated');
const checkMode = process.argv.includes('--check');

const schemaEntries = [
  {
    file: 'CredentialSource.schema.json',
    title: 'CredentialSource',
    schema: credentialSourceSchema,
  },
  {
    file: 'EnvProvenance.schema.json',
    title: 'EnvProvenance',
    schema: envProvenanceSchema,
  },
  {
    file: 'ExecutionContext.schema.json',
    title: 'ExecutionContext',
    schema: executionContextSchema,
  },
  {
    file: 'StartupPhase.schema.json',
    title: 'StartupPhase',
    schema: startupPhaseSchema,
  },
] as const;

const drifted: string[] = [];

await mkdir(generatedDir, { recursive: true });

for (const entry of schemaEntries) {
  const generated = {
    $id: `https://jefahnierocks.local/host-capability-substrate/schemas/${entry.file}`,
    title: entry.title,
    ...z.toJSONSchema(entry.schema),
  };
  const rendered = `${JSON.stringify(generated, null, 2)}\n`;
  const target = resolve(generatedDir, entry.file);

  if (checkMode) {
    const previous = await readFile(target, 'utf8').catch(() => '');
    if (previous !== rendered) {
      drifted.push(entry.file);
    }
    continue;
  }

  await writeFile(target, rendered, 'utf8');
}

if (drifted.length > 0) {
  process.stderr.write(`Schema drift detected: ${drifted.join(', ')}\n`);
  process.exitCode = 1;
} else if (checkMode) {
  process.stdout.write('generated schemas are current\n');
} else {
  process.stdout.write(`generated ${schemaEntries.length} JSON Schema files\n`);
}
