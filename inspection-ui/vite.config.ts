import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  base: "./",
  plugins: [react()],
  test: { environment: "jsdom", setupFiles: "./src/test/setup.ts", pool: "threads", maxWorkers: 1, minWorkers: 1 },
});
