import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'tests/',
        '**/*.config.js',
        '**/coverage/**'
      ]
    },
    include: ['tests/**/*.test.js'],
    globals: true,
    setupFiles: ['./tests/setup.js']
  }
});