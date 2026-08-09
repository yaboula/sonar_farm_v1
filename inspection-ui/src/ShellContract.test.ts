import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const shellPath = resolve(process.cwd(), "../nui-shell/index.html");
const shell = readFileSync(shellPath, "utf8");

describe("NUI shell inspection surface", () => {
  it("mounts the transparent, non-interactive third iframe", () => {
    expect(shell).toContain('id="inspection"');
    expect(shell).toContain('src="../inspection-ui/dist/index.html"');
    expect(shell).toContain("pointer-events:none");
  });

  it("routes inspection messages and closes it when a focus surface opens", () => {
    expect(shell).toContain("type.startsWith('inspection:')");
    expect(shell).toContain("frames.inspection.classList.toggle('is-visible', message.type !== 'inspection:close')");
    expect(shell).toContain("hideInspection(); activate('hub')");
    expect(shell).toContain("hideInspection(); activate('minigame')");
  });
});
