import "@fontsource/barlow-condensed/500.css";
import "@fontsource/barlow-condensed/600.css";
import "@fontsource/barlow-condensed/700.css";
import "@fontsource/source-sans-3/400.css";
import "@fontsource/source-sans-3/600.css";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import "./styles.css";

createRoot(document.getElementById("root")!).render(<StrictMode><App /></StrictMode>);

// Browser-only visual development. Vite removes this entire branch and its
// dynamic import from production, where Lua must send inspection:open first.
if (import.meta.env.DEV) {
  void import("./fixture").then(({ inspectionFixture }) => {
    window.postMessage({ type: "inspection:open", payload: inspectionFixture() }, "*");
  });
}
