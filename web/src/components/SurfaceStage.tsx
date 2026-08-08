import { type PropsWithChildren, useEffect, useState } from "react";
import { AppHeader } from "./AppHeader";
import { DevToolbar } from "./DevToolbar";
import { useHub } from "../store/HubContext";

const FRAME_WIDTH = 1584;
const FRAME_HEIGHT = 914;
const VIEWPORT_INSET = 36;

export function calculateSurfaceScale(viewportWidth: number, viewportHeight: number) {
  return Math.min(
    (viewportWidth - VIEWPORT_INSET * 2) / FRAME_WIDTH,
    (viewportHeight - VIEWPORT_INSET * 2) / FRAME_HEIGHT,
  );
}

function getStageScale() {
  return calculateSurfaceScale(window.innerWidth, window.innerHeight);
}

export function SurfaceStage({ children }: PropsWithChildren) {
  const { surface } = useHub();
  const [scale, setScale] = useState(() => getStageScale());

  useEffect(() => {
    const update = () => setScale(getStageScale());
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);

  const frameImage =
    surface === "office"
      ? "./assets/images/office-frame.webp"
      : "./assets/images/tablet-frame.webp";

  return (
    <div className={import.meta.env.DEV ? "world-stage preview-world" : "world-stage"}>
      <div
        className={"surface-stage surface-stage--" + surface}
        style={{ "--surface-scale": String(Math.max(scale, 0.35)) } as React.CSSProperties}
      >
        <div className="surface-screen" data-testid="surface-screen">
          <AppHeader />
          <main className="surface-content">{children}</main>
        </div>
        <img className="surface-frame-art" src={frameImage} alt="" aria-hidden="true" />
      </div>
      {import.meta.env.DEV ? <DevToolbar /> : null}
    </div>
  );
}
