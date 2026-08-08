import { describe, expect, it } from "vitest";
import { calculateSurfaceScale } from "./SurfaceStage";

const FRAME_WIDTH = 1584;
const FRAME_HEIGHT = 914;
const INSET = 72;

describe("calculateSurfaceScale", () => {
  it.each([
    [1280, 720],
    [1920, 1080],
    [2560, 1440],
    [3440, 1440],
  ])("fits the complete physical surface inside %ix%i", (width, height) => {
    const scale = calculateSurfaceScale(width, height);

    expect(FRAME_WIDTH * scale).toBeLessThanOrEqual(width - INSET + 0.01);
    expect(FRAME_HEIGHT * scale).toBeLessThanOrEqual(height - INSET + 0.01);
    expect(scale).toBeGreaterThan(0);
  });

  it("uses height rather than stretching on ultrawide viewports", () => {
    expect(calculateSurfaceScale(3440, 1440)).toBeCloseTo(
      calculateSurfaceScale(2560, 1440),
      6,
    );
  });
});
