import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './spec',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'api-e2e',
      use: { 
        // We are using APIRequestContext for backend E2E
      },
    },
  ],
});
