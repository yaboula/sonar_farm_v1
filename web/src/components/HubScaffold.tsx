import type { PropsWithChildren, ReactNode } from "react";

interface HubScaffoldProps extends PropsWithChildren {
  eyebrow: string;
  title: string;
  subtitle: string;
  toolbar?: ReactNode;
  aside?: ReactNode;
}

export function HubScaffold({
  eyebrow,
  title,
  subtitle,
  toolbar,
  aside,
  children,
}: HubScaffoldProps) {
  return (
    <section className="hub-view">
      <div className="hub-backdrop" aria-hidden="true" />
      <header className="hub-intro">
        <span>{eyebrow}</span>
        <h1>{title}</h1>
        <p>{subtitle}</p>
      </header>
      {toolbar ? <div className="hub-toolbar">{toolbar}</div> : null}
      <div className={aside ? "hub-body has-aside" : "hub-body"}>
        <div className="hub-primary">{children}</div>
        {aside ? <aside className="hub-aside">{aside}</aside> : null}
      </div>
    </section>
  );
}
