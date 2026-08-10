import { Plant } from "@phosphor-icons/react";
import { useEffect, useState } from "react";
import { NavLink } from "react-router-dom";
import { ROLE_LABELS } from "../hubPresentation";
import { useHub } from "../store/HubContext";
import type { HubRoute } from "../types";

const NAVIGATION: Array<{ id: HubRoute; label: string; path: string }> = [
  { id: "today", label: "Today", path: "/today" },
  { id: "fields", label: "Fields", path: "/fields" },
  { id: "work", label: "Work", path: "/work" },
  { id: "supplies", label: "Supplies", path: "/supplies" },
  { id: "company", label: "Company", path: "/company" },
];

export function AppHeader() {
  const { role, surface, capabilities, serverTime } = useHub();
  const surfaceLabel = surface === "office" ? "Office Terminal" : "Farm Tablet";
  const [now, setNow] = useState(() => (serverTime ? serverTime * 1000 : Date.now()));
  useEffect(() => {
    const receivedAt = Date.now();
    const authoritativeAt = serverTime ? serverTime * 1000 : receivedAt;
    const refresh = () => setNow(authoritativeAt + (Date.now() - receivedAt));
    refresh();
    const timer = window.setInterval(refresh, 30_000);
    return () => window.clearInterval(timer);
  }, [serverTime]);
  const serverDate = new Intl.DateTimeFormat("en-GB", {
    weekday: "long", day: "numeric", month: "short", year: "numeric", timeZone: "UTC",
  }).format(new Date(now));

  return (
    <header className="app-header">
      <div className="brand-lockup" aria-label="Sonar Farm">
        <Plant size={28} weight="regular" />
        <span>Sonar Farm</span>
      </div>
      <div className="header-divider" />
      <div className="surface-label">{surfaceLabel}</div>
      <div className="context-separator" />
      <div className="role-label">{ROLE_LABELS[role]}</div>
      <nav className="primary-nav" aria-label="Primary">
        {NAVIGATION.filter((item) => capabilities.routes.includes(item.id)).map((item) => (
          <NavLink
            key={item.id}
            to={item.path}
            className={({ isActive }) => (isActive ? "nav-link is-active" : "nav-link")}
          >
            {item.label}
          </NavLink>
        ))}
      </nav>
      <time className="server-date" dateTime={new Date(now).toISOString()}>
        {serverDate}
      </time>
    </header>
  );
}
