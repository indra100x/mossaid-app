"use client";

import { useCallback, useEffect, useState } from "react";
import {
  BadgeCheck,
  BarChart3,
  Check,
  Inbox,
  LogOut,
  RefreshCw,
  Scale,
  ScrollText,
  Users,
  Wallet,
  X,
} from "lucide-react";

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/api/v1";

// Session lives per browser tab (cleared on close). The access token lasts
// ~15 minutes; the refresh token silently renews it so the admin never has
// to handle tokens by hand.
const TOKEN_KEY = "mossaid_admin_token";
const REFRESH_KEY = "mossaid_admin_refresh";

type Tab = "verification" | "disputes" | "users" | "payouts" | "analytics" | "audit";

type Row = Record<string, string | number | boolean | null>;

// ---------------------------------------------------------------------------
// Data helpers (unchanged API contract)
// ---------------------------------------------------------------------------

async function readJson(res: Response): Promise<Row[] | Row> {
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`${res.status} ${text.slice(0, 200)}`);
  }
  if (res.status === 204) return [];
  return (await res.json()) as Row[] | Row;
}

/** Exchange the stored refresh token for a fresh access token (null = relogin needed). */
async function refreshAccessToken(): Promise<string | null> {
  const refresh = window.sessionStorage.getItem(REFRESH_KEY);
  if (!refresh) return null;
  try {
    const res = await fetch(`${API_BASE}/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refresh_token: refresh }),
    });
    if (!res.ok) return null;
    const body = (await res.json()) as { access_token: string };
    window.sessionStorage.setItem(TOKEN_KEY, body.access_token);
    return body.access_token;
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Ledger formatting — tabular numerals, fr grouping, DZD everywhere money moves
// ---------------------------------------------------------------------------

const numFmt = new Intl.NumberFormat("fr-FR");
const dzdFmt = new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 0 });

function fmtDZD(v: string | number | boolean | null): string {
  return `${dzdFmt.format(Number(v))} DZD`;
}

function fmtDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString("fr-FR", { day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit" });
}

function shortId(id: string): string {
  return id.length > 8 ? `${id.slice(0, 8)}…` : id;
}

// Status → meaning. Color carries state, never decoration.
type Tone = "ok" | "warn" | "bad" | "mute";
function toneFor(status: string): Tone {
  const s = status.toLowerCase();
  if (["approved", "verified", "released", "completed", "resolved", "disbursed"].includes(s)) return "ok";
  if (["rejected", "suspended", "refunded", "failed", "declined", "cancelled"].includes(s)) return "bad";
  if (["pending", "open", "requested", "held", "disputed", "accepted", "scheduled", "in_progress"].includes(s)) return "warn";
  return "mute";
}

const TONE_CLASSES: Record<Tone, string> = {
  ok: "bg-success-wash text-success-ink ring-success/20",
  warn: "bg-warn-wash text-warn-ink ring-warn/25",
  bad: "bg-danger-wash text-danger-ink ring-danger/20",
  mute: "bg-wash text-soft ring-soft/10",
};

function Pill({ status }: { status: string }) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-xs font-medium ring-1 ring-inset ${TONE_CLASSES[toneFor(status)]}`}
    >
      <span className="h-1.5 w-1.5 rounded-full bg-current" />
      {status}
    </span>
  );
}

// ---------------------------------------------------------------------------
// Chrome — one accent (teal), hairline borders, no shadows
// ---------------------------------------------------------------------------

function Panel(props: { title: string; hint: string; count?: number; children: React.ReactNode }) {
  return (
    <section className="overflow-hidden rounded-lg border border-line bg-card">
      <div className="flex items-baseline justify-between gap-3 border-b border-line px-4 py-3">
        <div>
          <h2 className="text-sm font-semibold">{props.title}</h2>
          <p className="mt-0.5 text-xs text-soft">{props.hint}</p>
        </div>
        {props.count !== undefined && (
          <span className="tnum text-2xl font-semibold tabular-nums">{numFmt.format(props.count)}</span>
        )}
      </div>
      <div className="px-4 py-3">{props.children}</div>
    </section>
  );
}

function Empty({ label }: { label: string }) {
  return (
    <div className="flex flex-col items-center gap-2 py-8 text-center">
      <Inbox className="h-6 w-6 text-ghost" strokeWidth={1.5} />
      <p className="text-sm text-soft">{label}</p>
    </div>
  );
}

function SkeletonRows() {
  return (
    <div className="flex flex-col gap-2 py-1" aria-label="Loading">
      {[0, 1, 2].map((i) => (
        <div key={i} className="h-10 animate-pulse rounded-md bg-wash" />
      ))}
    </div>
  );
}

// Action language is consistent everywhere: accent-solid moves money/state
// forward (approve, release, disburse); outline destroys or sends back
// (reject, refund, suspend).
function SolidButton(props: React.ButtonHTMLAttributes<HTMLButtonElement>) {
  const { className = "", ...rest } = props;
  return (
    <button
      {...rest}
      className={`inline-flex items-center gap-1.5 rounded-md bg-accent px-2.5 py-1.5 text-xs font-medium text-accent-ink hover:bg-accent-deep focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent disabled:opacity-50 ${className}`}
    />
  );
}

function OutlineButton(props: React.ButtonHTMLAttributes<HTMLButtonElement> & { danger?: boolean }) {
  const { danger, className = "", ...rest } = props;
  const tone = danger
    ? "border-danger/40 text-danger-ink hover:bg-danger-wash focus-visible:outline-danger"
    : "border-line text-soft hover:bg-wash focus-visible:outline-accent";
  return (
    <button
      {...rest}
      className={`inline-flex items-center gap-1.5 rounded-md border px-2.5 py-1.5 text-xs font-medium focus-visible:outline-2 focus-visible:outline-offset-2 disabled:opacity-50 ${tone} ${className}`}
    />
  );
}

const TABS: { id: Tab; label: string; icon: React.ReactNode }[] = [
  { id: "verification", label: "Verification", icon: <BadgeCheck className="h-4 w-4" strokeWidth={2} /> },
  { id: "disputes", label: "Disputes", icon: <Scale className="h-4 w-4" strokeWidth={2} /> },
  { id: "users", label: "Users", icon: <Users className="h-4 w-4" strokeWidth={2} /> },
  { id: "payouts", label: "Payouts", icon: <Wallet className="h-4 w-4" strokeWidth={2} /> },
  { id: "analytics", label: "Analytics", icon: <BarChart3 className="h-4 w-4" strokeWidth={2} /> },
  { id: "audit", label: "Audit log", icon: <ScrollText className="h-4 w-4" strokeWidth={2} /> },
];

const TAB_META: Record<Tab, { title: string; hint: string }> = {
  verification: { title: "Verification queue", hint: "Craftsman dossiers awaiting a stamp — approval grants the Verified badge." },
  disputes: { title: "Dispute resolution", hint: "Frozen escrow. Refund the client or release to the craftsman." },
  users: { title: "Users", hint: "Suspended accounts get 403 on every API call until reinstated." },
  payouts: { title: "Payout reconciliation", hint: "Released escrow awaiting manual disbursement (v1)." },
  analytics: { title: "Platform health", hint: "Bookings, GMV, verification and dispute rates — per product spec §6." },
  audit: { title: "Audit ledger", hint: "Every mutating admin action. Latest 100 entries." },
};

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

export default function Home() {
  // Server and first client render must match: start blank, hydrate from
  // storage after mount (avoids hydration mismatch).
  const [mounted, setMounted] = useState(false);
  const [authed, setAuthed] = useState(false);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loginError, setLoginError] = useState<string | null>(null);
  const [loginBusy, setLoginBusy] = useState(false);
  const [token, setToken] = useState("");
  const [tab, setTab] = useState<Tab>("verification");
  const [rows, setRows] = useState<Row[]>([]);
  const [stats, setStats] = useState<Row | null>(null);
  const [pendingCount, setPendingCount] = useState(0);
  const [openDisputes, setOpenDisputes] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const logout = useCallback((message?: string) => {
    window.sessionStorage.removeItem(TOKEN_KEY);
    window.sessionStorage.removeItem(REFRESH_KEY);
    setToken("");
    setAuthed(false);
    setRows([]);
    setStats(null);
    if (message) setLoginError(message);
  }, []);

  // Authenticated request: silently renews an expired access token once.
  const request = useCallback(
    async (path: string, init?: RequestInit, retry = true): Promise<Row[] | Row> => {
      const doFetch = (t: string) =>
        fetch(`${API_BASE}${path}`, {
          ...init,
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${t}`,
            ...(init?.headers ?? {}),
          },
        });
      let res = await doFetch(token);
      if (res.status === 401 && retry) {
        const renewed = await refreshAccessToken();
        if (renewed) {
          setToken(renewed);
          res = await doFetch(renewed);
        } else {
          logout("Session expired — please log in again.");
          throw new Error("401 Session expired");
        }
      }
      return readJson(res);
    },
    [token, logout]
  );

  // Sidebar attention badges — cheap head-count queries, refreshed with data.
  const loadCounts = useCallback(async () => {
    try {
      const [v, d] = await Promise.all([
        request("/admin/verification?status_filter=pending", undefined, false),
        request("/admin/disputes", undefined, false),
      ]);
      setPendingCount(Array.isArray(v) ? v.length : 0);
      setOpenDisputes(Array.isArray(d) ? d.filter((x) => (x as Row).status === "open").length : 0);
    } catch {
      // Badges are advisory; tab content surfaces real errors.
    }
  }, [request]);

  // Hydrate persisted session after mount (client-only storage).
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMounted(true);
    const saved = window.sessionStorage.getItem(TOKEN_KEY);
    if (saved) {
      setToken(saved);
      setAuthed(true);
    } else if (window.sessionStorage.getItem(REFRESH_KEY)) {
      void refreshAccessToken().then((renewed) => {
        if (renewed) {
          setToken(renewed);
          setAuthed(true);
        }
      });
    }
  }, []);

  const load = useCallback(async () => {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      if (tab === "verification") {
        const data = await request("/admin/verification?status_filter=pending");
        setRows(Array.isArray(data) ? data : []);
      } else if (tab === "disputes") {
        const data = await request("/admin/disputes");
        setRows(Array.isArray(data) ? data : []);
      } else if (tab === "users") {
        const data = await request("/admin/users");
        setRows(Array.isArray(data) ? data : []);
      } else if (tab === "payouts") {
        const data = await request("/admin/payouts");
        setRows(Array.isArray(data) ? data : []);
      } else if (tab === "analytics") {
        const data = await request("/admin/analytics");
        setStats(data as Row);
        setRows([]);
      } else {
        const data = await request("/admin/audit-logs");
        setRows(Array.isArray(data) ? data : []);
      }
      void loadCounts();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Load failed");
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [token, tab, request, loadCounts]);

  // Data fetch on token/tab change (standard sync-external-system effect).
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void load();
  }, [load]);

  const act = async (path: string, method = "POST", body?: Row) => {
    setError(null);
    try {
      await request(path, { method, body: body ? JSON.stringify(body) : undefined });
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Action failed");
    }
  };

  const login = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoginBusy(true);
    setLoginError(null);
    try {
      const res = await fetch(`${API_BASE}/auth/admin-login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password }),
      });
      if (res.status === 401) {
        setLoginError("Invalid username or password");
        return;
      }
      if (res.status === 503) {
        setLoginError("Admin login is not configured on the server");
        return;
      }
      if (!res.ok) {
        setLoginError(`Login failed (${res.status})`);
        return;
      }
      const body = (await res.json()) as { access_token: string; refresh_token: string };
      window.sessionStorage.setItem(TOKEN_KEY, body.access_token);
      window.sessionStorage.setItem(REFRESH_KEY, body.refresh_token);
      setToken(body.access_token);
      setAuthed(true);
      setPassword("");
    } catch {
      setLoginError("Cannot reach the API — is the backend running?");
    } finally {
      setLoginBusy(false);
    }
  };

  if (!mounted) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-paper">
        <p className="text-sm text-soft">Loading…</p>
      </main>
    );
  }

  if (!authed) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-paper p-6">
        <div className="w-full max-w-sm">
          <div className="mb-6 flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-ink text-lg font-bold text-white">
              M
            </div>
            <div>
              <p className="text-base font-semibold leading-tight">Mossaid</p>
              <p className="text-xs text-soft">Operations ledger</p>
            </div>
          </div>
          <form onSubmit={login} className="rounded-lg border border-line bg-card p-5">
            <h1 className="text-sm font-semibold">Admin sign in</h1>
            <p className="mt-0.5 text-xs text-soft">Verification, disputes, payouts.</p>
            <label htmlFor="login-user" className="mt-4 block text-xs font-medium text-soft">
              Username
            </label>
            <input
              id="login-user"
              type="text"
              autoComplete="username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="mt-1 w-full rounded-md border border-line bg-card px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-accent"
            />
            <label htmlFor="login-pass" className="mt-3 block text-xs font-medium text-soft">
              Password
            </label>
            <input
              id="login-pass"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="mt-1 w-full rounded-md border border-line bg-card px-3 py-2 text-sm focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-accent"
            />
            {loginError && <p className="mt-3 text-xs text-danger-ink">{loginError}</p>}
            <button
              type="submit"
              disabled={loginBusy}
              className="mt-4 w-full rounded-md bg-accent px-3 py-2 text-sm font-medium text-accent-ink hover:bg-accent-deep focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent disabled:opacity-50"
            >
              {loginBusy ? "Signing in…" : "Sign in"}
            </button>
          </form>
        </div>
      </main>
    );
  }

  const meta = TAB_META[tab];

  const navButton = (t: (typeof TABS)[number]) => {
    const active = tab === t.id;
    const badge = t.id === "verification" ? pendingCount : t.id === "disputes" ? openDisputes : 0;
    return (
      <button
        key={t.id}
        onClick={() => setTab(t.id)}
        aria-current={active ? "page" : undefined}
        className={`flex w-full items-center gap-2.5 rounded-md px-3 py-2 text-sm font-medium focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-accent ${
          active ? "bg-ink text-white" : "text-soft hover:bg-wash hover:text-ink"
        }`}
      >
        {t.icon}
        <span className="flex-1 text-left">{t.label}</span>
        {badge > 0 && (
          <span
            className={`tnum rounded-md px-1.5 py-0.5 text-xs font-semibold tabular-nums ${
              active ? "bg-card/15 text-white" : "bg-warn-wash text-warn-ink"
            }`}
          >
            {numFmt.format(badge)}
          </span>
        )}
      </button>
    );
  };

  return (
    <div className="min-h-screen bg-paper text-ink md:flex">
      {/* Sidebar — same ground as content, separated by a hairline */}
      <aside className="hidden w-60 shrink-0 flex-col border-r border-line md:flex">
        <div className="flex items-center gap-2.5 px-4 pb-4 pt-5">
          <div className="flex h-8 w-8 items-center justify-center rounded-md bg-ink text-sm font-bold text-white">
            M
          </div>
          <div>
            <p className="text-sm font-semibold leading-tight">Mossaid</p>
            <p className="text-[11px] leading-tight text-soft">Operations ledger</p>
          </div>
        </div>
        <nav className="flex flex-1 flex-col gap-0.5 px-3" aria-label="Sections">
          {TABS.map(navButton)}
        </nav>
        <div className="border-t border-line p-3">
          <div className="mb-2 flex items-center gap-2 px-1">
            <span className="h-1.5 w-1.5 rounded-full bg-success" />
            <span className="text-xs text-soft">local · {API_BASE.replace(/^https?:\/\//, "")}</span>
          </div>
          <button
            onClick={() => logout()}
            className="flex w-full items-center gap-2.5 rounded-md px-3 py-2 text-sm font-medium text-soft hover:bg-wash hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-accent"
          >
            <LogOut className="h-4 w-4" strokeWidth={2} />
            Log out
          </button>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        {/* Mobile top bar */}
        <div className="flex items-center justify-between gap-3 border-b border-line px-4 py-3 md:hidden">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-md bg-ink text-xs font-bold text-white">
              M
            </div>
            <p className="text-sm font-semibold">Mossaid</p>
          </div>
          <button
            onClick={() => logout()}
            className="inline-flex items-center gap-1.5 rounded-md border border-line px-2.5 py-1.5 text-xs font-medium text-soft"
          >
            <LogOut className="h-3.5 w-3.5" strokeWidth={2} />
            Log out
          </button>
        </div>

        {/* Section header */}
        <div className="flex items-start justify-between gap-3 border-b border-line px-4 py-4 md:px-8">
          <div>
            <h1 className="text-lg font-semibold tracking-tight">{meta.title}</h1>
            <p className="mt-0.5 text-xs text-soft">{meta.hint}</p>
          </div>
          <button
            onClick={() => void load()}
            disabled={loading}
            className="inline-flex shrink-0 items-center gap-1.5 rounded-md border border-line px-2.5 py-1.5 text-xs font-medium text-soft hover:bg-card focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent disabled:opacity-50"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${loading ? "animate-spin" : ""}`} strokeWidth={2} />
            {loading ? "Loading…" : "Refresh"}
          </button>
        </div>

        {/* Mobile section nav */}
        <nav className="flex gap-1.5 overflow-x-auto border-b border-line px-4 py-2 md:hidden" aria-label="Sections">
          {TABS.map((t) => (
            <button
              key={t.id}
              onClick={() => setTab(t.id)}
              className={`flex shrink-0 items-center gap-1.5 rounded-md px-2.5 py-1.5 text-xs font-medium ${
                tab === t.id ? "bg-ink text-white" : "text-soft hover:bg-wash"
              }`}
            >
              {t.icon}
              {t.label}
            </button>
          ))}
        </nav>

        <main className="w-full max-w-5xl flex-1 px-4 py-4 md:px-8 md:py-6">
          {error && (
            <p className="mb-3 rounded-lg border border-danger/25 bg-danger-wash p-3 text-xs text-danger-ink">{error}</p>
          )}

          {tab === "analytics" && <AnalyticsView stats={stats} loading={loading} />}

          {tab === "verification" && (
            <Panel title="Dossiers awaiting a stamp" hint="ID + trade credential per craftsman." count={pendingCount}>
              {loading && rows.length === 0 ? (
                <SkeletonRows />
              ) : rows.length === 0 ? (
                <Empty label="Queue clear — nothing awaiting review." />
              ) : (
                <ul className="divide-y divide-line">
                  {rows.map((d) => (
                    <li key={String(d.id)} className="flex flex-wrap items-center gap-x-4 gap-y-2 py-3">
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-medium">
                          {String(d.doc_type).replace(/_/g, " ")}
                          <span className="ml-2 font-mono text-xs font-normal text-soft">{shortId(String(d.user_id))}</span>
                        </p>
                        <p className="mt-0.5 text-xs text-soft">Filed {fmtDate(String(d.created_at))}</p>
                      </div>
                      <Pill status={String(d.status)} />
                      <div className="flex gap-2">
                        <SolidButton onClick={() => void act(`/admin/verification/${d.id}/review`, "POST", { decision: "approved" })}>
                          <Check className="h-3.5 w-3.5" strokeWidth={2.5} />
                          Approve
                        </SolidButton>
                        <OutlineButton danger onClick={() => void act(`/admin/verification/${d.id}/review`, "POST", { decision: "rejected" })}>
                          <X className="h-3.5 w-3.5" strokeWidth={2.5} />
                          Reject
                        </OutlineButton>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </Panel>
          )}

          {tab === "disputes" && (
            <Panel title="Frozen escrow" hint="Refund returns money to the client; release pays the craftsman." count={openDisputes}>
              {loading && rows.length === 0 ? (
                <SkeletonRows />
              ) : rows.length === 0 ? (
                <Empty label="No disputes — escrow is flowing." />
              ) : (
                <ul className="divide-y divide-line">
                  {rows.map((d) => (
                    <li key={String(d.id)} className="flex flex-wrap items-center gap-x-4 gap-y-2 py-3">
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-medium">
                          Payment <span className="font-mono text-xs font-normal text-soft">{shortId(String(d.payment_id))}</span>
                        </p>
                        <p className="mt-0.5 text-xs text-soft">
                          “{String(d.reason ?? "no reason given")}” · filed {fmtDate(String(d.created_at))}
                        </p>
                      </div>
                      <Pill status={String(d.status)} />
                      {String(d.status) === "open" ? (
                        <div className="flex gap-2">
                          <OutlineButton danger onClick={() => void act(`/admin/disputes/${d.id}/resolve?decision=refund`, "POST")}>
                            Refund client
                          </OutlineButton>
                          <SolidButton onClick={() => void act(`/admin/disputes/${d.id}/resolve?decision=release`, "POST")}>
                            Release
                          </SolidButton>
                        </div>
                      ) : (
                        <span className="text-xs text-soft">settled</span>
                      )}
                    </li>
                  ))}
                </ul>
              )}
            </Panel>
          )}

          {tab === "users" && <UsersTable rows={rows} loading={loading} act={act} />}

          {tab === "payouts" && (
            <Panel title="Pending disbursement" hint="Released escrow awaiting manual payout (v1).">
              {loading && rows.length === 0 ? (
                <SkeletonRows />
              ) : rows.length === 0 ? (
                <Empty label="Nothing pending payout." />
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-sm">
                    <thead>
                      <tr className="border-b border-line text-xs text-soft">
                        <th className="py-2 pr-4 font-medium">Craftsman</th>
                        <th className="py-2 pr-4 font-medium">Amount</th>
                        <th className="py-2 pr-4 font-medium">Released</th>
                        <th className="py-2 text-right font-medium">Action</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-line">
                      {rows.map((p) => (
                        <tr key={String(p.id)} className="hover:bg-wash">
                          <td className="py-2.5 pr-4 font-mono text-xs text-soft">{shortId(String(p.craftsman_id))}</td>
                          <td className="tnum py-2.5 pr-4 font-semibold tabular-nums">{fmtDZD(p.amount)}</td>
                          <td className="py-2.5 pr-4 text-xs text-soft">{p.released_at ? fmtDate(String(p.released_at)) : "—"}</td>
                          <td className="py-2.5 text-right">
                            <SolidButton onClick={() => void act(`/admin/payouts/${p.id}/disburse`, "POST")}>
                              Mark disbursed
                            </SolidButton>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </Panel>
          )}

          {tab === "audit" && (
            <Panel title="Audit ledger" hint="Every mutating admin action. Latest 100.">
              {loading && rows.length === 0 ? (
                <SkeletonRows />
              ) : rows.length === 0 ? (
                <Empty label="No audit entries yet." />
              ) : (
                <ol className="divide-y divide-line font-mono text-xs">
                  {rows.map((l) => (
                    <li key={String(l.id)} className="flex flex-wrap items-baseline gap-x-3 py-2">
                      <span className="text-soft">{fmtDate(String(l.created_at))}</span>
                      <span className="rounded bg-wash px-1.5 py-0.5 font-semibold text-soft">{String(l.action)}</span>
                      <span className="text-soft">
                        {String(l.target_type)}/{shortId(String(l.target_id ?? ""))}
                      </span>
                      <span className="ml-auto text-soft">by {shortId(String(l.actor_id ?? "?"))}</span>
                    </li>
                  ))}
                </ol>
              )}
            </Panel>
          )}

          <p className="mt-4 text-[11px] text-soft">All monetary values in DZD · every action above is audit-logged.</p>
        </main>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Analytics — hero GMV, rate bars, head counts. Numbers carry the section.
// ---------------------------------------------------------------------------

function AnalyticsView({ stats, loading }: { stats: Row | null; loading: boolean }) {
  if (!stats) {
    return (
      <Panel title="Platform health" hint="Live marketplace vitals.">
        {loading ? <SkeletonRows /> : <Empty label="No analytics yet — refresh to load." />}
      </Panel>
    );
  }
  const pct = (v: string | number | boolean | null) => Math.max(0, Math.min(100, Number(v)));
  const rate = (label: string, value: string | number | boolean | null, bar: string, note?: string) => (
    <div className="rounded-lg border border-line bg-card p-4">
      <p className="text-xs text-soft">{label}</p>
      <p className="tnum mt-1 text-2xl font-semibold tabular-nums">{numFmt.format(Number(value))}%</p>
      <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-wash">
        <div className={`h-full rounded-full ${bar}`} style={{ width: `${pct(value)}%` }} />
      </div>
      {note && <p className="mt-1.5 text-[11px] text-soft">{note}</p>}
    </div>
  );
  return (
    <div className="flex flex-col gap-3">
      <div className="rounded-lg border border-line bg-ink p-5 text-white">
        <p className="text-xs text-white/60">Gross merchandise value</p>
        <p className="tnum mt-1 text-3xl font-semibold tabular-nums">{fmtDZD(stats.total_gmv)}</p>
        <p className="tnum mt-1 text-xs tabular-nums text-white/60">
          {numFmt.format(Number(stats.total_bookings))} bookings · {numFmt.format(Number(stats.completed_bookings))} completed
        </p>
      </div>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        {rate("Completion rate", stats.completion_rate, "bg-accent")}
        {rate("Craftsman verification", stats.verification_rate, "bg-accent", `${numFmt.format(Number(stats.verified_craftsmen))} of ${numFmt.format(Number(stats.total_craftsmen))} verified`)}
        {rate("Dispute rate", stats.dispute_rate, "bg-danger", `${numFmt.format(Number(stats.total_disputes))} open — investigate above 5%`)}
      </div>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {[
          ["Users", stats.total_users],
          ["Craftsmen", stats.total_craftsmen],
          ["Bookings", stats.total_bookings],
          ["Disputes", stats.total_disputes],
        ].map(([label, value]) => (
          <div key={label as string} className="rounded-lg border border-line bg-card p-4">
            <p className="text-xs text-soft">{label}</p>
            <p className="tnum mt-1 text-xl font-semibold tabular-nums">{numFmt.format(Number(value))}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Users — the one true table: scan, compare, act
// ---------------------------------------------------------------------------

function UsersTable({ rows, loading, act }: { rows: Row[]; loading: boolean; act: (path: string, method?: string, body?: Row) => Promise<void> }) {
  return (
    <Panel title="Accounts" hint="Suspended accounts get 403 on every API call until reinstated.">
      {loading && rows.length === 0 ? (
        <SkeletonRows />
      ) : rows.length === 0 ? (
        <Empty label="No users found." />
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-line text-xs text-soft">
                <th className="py-2 pr-4 font-medium">Phone</th>
                <th className="py-2 pr-4 font-medium">Role</th>
                <th className="py-2 pr-4 font-medium">Status</th>
                <th className="py-2 pr-4 font-medium">Joined</th>
                <th className="py-2 text-right font-medium">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {rows.map((u) => {
                const suspended = u.is_suspended === true;
                return (
                  <tr key={String(u.id)} className="hover:bg-wash">
                    <td className="tnum py-2.5 pr-4 tabular-nums">{String(u.phone)}</td>
                    <td className="py-2.5 pr-4 text-xs text-soft">{String(u.role)}</td>
                    <td className="py-2.5 pr-4">
                      <Pill status={suspended ? "suspended" : u.is_verified ? "verified" : "pending"} />
                    </td>
                    <td className="py-2.5 pr-4 text-xs text-soft">{u.created_at ? fmtDate(String(u.created_at)) : "—"}</td>
                    <td className="py-2.5 text-right">
                      {suspended ? (
                        <OutlineButton onClick={() => void act(`/admin/users/${u.id}/reinstate`, "POST")}>
                          Reinstate
                        </OutlineButton>
                      ) : (
                        <OutlineButton danger onClick={() => void act(`/admin/users/${u.id}/suspend`, "POST", { reason: "admin action" })}>
                          Suspend
                        </OutlineButton>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </Panel>
  );
}
