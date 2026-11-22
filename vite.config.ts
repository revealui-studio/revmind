import path from 'node:path';
import { fileURLToPath } from 'node:url';
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// @revealui/utils reads process.env in code that ships to the browser.
// Vite already replaces NODE_ENV. These remaining keys otherwise stay as a
// bare `process` and the dev server renders a blank page.
const browserProcessEnv = {
  'process.env.LOG_LEVEL': JSON.stringify(process.env.LOG_LEVEL ?? 'info'),
  'process.env.DATABASE_SSL_REJECT_UNAUTHORIZED': JSON.stringify(
    process.env.DATABASE_SSL_REJECT_UNAUTHORIZED ?? '',
  ),
};

export default defineConfig({
  define: browserProcessEnv,
  optimizeDeps: {
    rolldownOptions: {
      transform: {
        define: browserProcessEnv,
      },
    },
  },
  plugins: [tailwindcss(), react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './app'),
    },
  },
  server: {
    port: 3002,
    open: false,
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
  },
  publicDir: 'public',
});
