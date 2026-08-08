import { Plant } from "@phosphor-icons/react";
import { NavLink } from "react-router-dom";
import { ROLE_LABELS } from "../data/fixtures";
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
  const { role, surface, capabilities } = useHub();
  const surfaceLabel = surface === "office" ? "Office Terminal" : "Farm Tablet";

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
      <time className="server-date" dateTime="2026-08-08">
        Saturday, 8 Aug 2026
      </time>
    </header>
  );
}
