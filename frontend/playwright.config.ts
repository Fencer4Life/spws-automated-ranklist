import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  timeout: 30000,
  use: {
    baseURL: 'http://localhost:4174',
  },
  webServer: {
    command: 'npm run build:ce && npx vite preview --config vite.config.ce.ts --port 4174',
    port: 4174,
    reuseExistingServer: true,
    timeout: 10000,
  },
})
