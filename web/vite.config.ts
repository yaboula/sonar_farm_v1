import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  base: "./",
  build: {
    emptyOutDir: true,
  },
  optimizeDeps: {
    include: ["react", "react-dom/client", "react-router-dom"],
  },
  server: {
    host: "0.0.0.0",
    allowedHosts: ["terminal.local", "localhost"],
    warmup: {
      clientFiles: ["./src/main.tsx"],
    },
  },
  plugins: [react(), tailwindcss()],
  test: {
    environment: "jsdom",
    setupFiles: "./src/test/setup.ts",
    css: true,
    include: ["src/**/*.test.{ts,tsx}"],
  },
});
