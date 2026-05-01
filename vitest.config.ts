import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    exclude: ['**/node_modules/**', '**/dist/**', '**/build/**', '**/.logs/**'],
    include: ['packages/**/*.test.ts', 'tests/**/*.test.ts'],
  },
});
