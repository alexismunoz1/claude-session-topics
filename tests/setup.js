import { vi } from 'vitest';
import { tmpdir } from 'os';
import { join } from 'path';
import { mkdtempSync, writeFileSync, mkdirSync, rmSync, existsSync } from 'fs';

// Mock paths for testing
let mockHomeDir;
let mockSettingsPath;

// Setup before all tests
export function setupTestEnvironment() {
  // Create a temporary directory for mocks
  mockHomeDir = mkdtempSync(join(tmpdir(), 'claude-session-topics-test-'));
  mockSettingsPath = join(mockHomeDir, '.claude', 'settings.json');
  
  // Create .claude directory
  mkdirSync(join(mockHomeDir, '.claude'), { recursive: true });
  
  // Mock os.homedir()
  vi.mock('os', async () => {
    const actual = await vi.importActual('os');
    return {
      ...actual,
      homedir: () => mockHomeDir,
    };
  });
  
  return { mockHomeDir, mockSettingsPath };
}

// Cleanup after all tests
export function cleanupTestEnvironment() {
  if (mockHomeDir && existsSync(mockHomeDir)) {
    rmSync(mockHomeDir, { recursive: true, force: true });
  }
}

// Helper to create mock settings.json
export function createMockSettings(content = {}) {
  mkdirSync(join(mockHomeDir, '.claude'), { recursive: true });
  writeFileSync(mockSettingsPath, JSON.stringify(content, null, 2));
  return mockSettingsPath;
}

// Helper to read mock settings.json
export function readMockSettings() {
  if (!existsSync(mockSettingsPath)) {
    return {};
  }
  const fs = require('fs');
  return JSON.parse(fs.readFileSync(mockSettingsPath, 'utf8'));
}

// Global test setup
beforeAll(() => {
  setupTestEnvironment();
});

afterAll(() => {
  cleanupTestEnvironment();
});

// Reset mocks before each test
beforeEach(() => {
  vi.clearAllMocks();
});
