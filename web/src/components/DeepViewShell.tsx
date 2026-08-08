import { ArrowLeft, CaretRight } from "@phosphor-icons/react";
import type { PropsWithChildren, ReactNode } from "react";

export function StatusPill({ children, tone = "neutral" }: { children: ReactNode; tone?: "neutral" | "active" | "success" | "warning" | "danger" }) {
  return <span className={`domain-status domain-status--${tone}`}>{children}</span>;
}

export function DeepViewShell({
  eyebrow,
  title,
  subtitle,
  breadcrumb,
  backLabel,
  onBack,
  status,
  children,
  actionBar,
}: PropsWithChildren<{
  eyebrow: string;
  title: string;
  subtitle: string;
  breadcrumb: string[];
  backLabel: string;
  onBack: () => void;
  status?: ReactNode;
  actionBar?: ReactNode;
}>) {
  return (
    <section className="domain-detail-view">
      <div className="detail-backdrop" aria-hidden="true" />
      <header className="domain-topbar">
        <button type="button" onClick={onBack}><ArrowLeft size={18} />{backLabel}</button>
        <nav aria-label="Breadcrumb">
          {breadcrumb.map((item, index) => (
            <span key={`${item}-${index}`}>{index ? <CaretRight size={13} /> : null}<strong>{item}</strong></span>
          ))}
        </nav>
      </header>
      <div className="domain-detail-header">
        <div>
          <span>{eyebrow}</span>
          <h1>{title}</h1>
          <p>{subtitle}</p>
        </div>
        {status}
      </div>
      <div className={actionBar ? "domain-detail-scroll has-actionbar" : "domain-detail-scroll"}>{children}</div>
      {actionBar ? <footer className="domain-action-bar">{actionBar}</footer> : null}
    </section>
  );
}

export function DetailCard({ title, eyebrow, children, className = "" }: PropsWithChildren<{ title: string; eyebrow?: string; className?: string }>) {
  return (
    <section className={`domain-card ${className}`.trim()}>
      {eyebrow ? <span>{eyebrow}</span> : null}
      <h2>{title}</h2>
      <div className="domain-card-content">{children}</div>
    </section>
  );
}

export function FactList({ facts }: { facts: Array<{ label: string; value: ReactNode }> }) {
  return (
    <dl className="domain-facts">
      {facts.map((fact) => <div key={fact.label}><dt>{fact.label}</dt><dd>{fact.value}</dd></div>)}
    </dl>
  );
}
