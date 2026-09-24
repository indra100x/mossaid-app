"use client";

import { useCallback, useEffect, useState } from "react";

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/api/v1";

// Session lives per browser tab (cleared on close). The access token lasts
// ~15 minutes; the refresh token silently renews it so the admin never has
// to handle tokens by hand.
const TOKEN_KEY = "mossaid_admin_token";
const REFRESH_KEY = "mossaid_admin_refresh";

type Tab = "verification" | "disputes" | "users" | "payouts" | "analytics" | "audit";

type Row = Record<string, string | number | boolean | null>;

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

function Section(props: { title: string; hint: string; children: React.ReactNode }) {
  return (
    <section className="rounded border p-4">
      <h2 className="font-semibold">{props.title}</h2>
      <p className="mb-3 text-sm text-zinc-500">{props.hint}</p>
      {props.children}
    </section>
  );
}

export default function Home() {
  // Server and first client render must match: start unauthenticated with no
  // token, then hydrate from storage after mount (avoids hydration mismatch).
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
    } catch (e) {
      setError(e instanceof Error ? e.message : "Load failed");
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [token, tab, request]);

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

  const tabs: { id: Tab; label: string }[] = [
    { id: "verification", label: "Verification Queue" },
    { id: "disputes", label: "Disputes" },
    { id: "users", label: "Users" },
    { id: "payouts", label: "Payouts" },
    { id: "analytics", label: "Analytics" },
    { id: "audit", label: "Audit Log" },
  ];

  if (!mounted) {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center gap-4 p-8">
        <h1 className="text-3xl font-bold">Mossaid Admin</h1>
        <p className="text-sm text-zinc-500">Loading…</p>
      </main>
    );
  }

  if (!authed) {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center gap-4 p-8">
        <h1 className="text-3xl font-bold">Mossaid Admin</h1>
        <form onSubmit={login} className="flex flex-col gap-3 rounded border p-4">
          <label htmlFor="login-user" className="text-sm font-medium">
            Username
          </label>
          <input
            id="login-user"
            type="text"
            autoComplete="username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="rounded border px-3 py-2 text-sm"
          />
          <label htmlFor="login-pass" className="text-sm font-medium">
            Password
          </label>
          <input
            id="login-pass"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="rounded border px-3 py-2 text-sm"
          />
          {loginError && <p className="text-sm text-red-700">{loginError}</p>}
          <button
            type="submit"
            disabled={loginBusy}
            className="rounded bg-zinc-900 px-3 py-2 text-sm text-white disabled:opacity-50"
          >
            {loginBusy ? "Logging in…" : "Log in"}
          </button>
        </form>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-6xl flex-col gap-4 p-8">
      <header className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold">Mossaid Admin</h1>
          <p className="mt-1 text-sm text-zinc-600">
            Verification, disputes, suspension, payouts, analytics (GMV, completion, verification &amp;
            dispute rates). Every action is audit-logged. Session renews itself; if you see “Session
            expired”, just log in again.
          </p>
        </div>
        <button onClick={() => logout()} className="shrink-0 rounded border px-3 py-1.5 text-sm">
          Log out
        </button>
      </header>

      <nav className="flex flex-wrap gap-2">
        {tabs.map((t) => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={`rounded border px-3 py-1.5 text-sm ${tab === t.id ? "bg-zinc-900 text-white" : "bg-white"}`}
          >
            {t.label}
          </button>
        ))}
        <button onClick={() => void load()} className="rounded border px-3 py-1.5 text-sm" disabled={loading}>
          {loading ? "Loading…" : "Refresh"}
        </button>
      </nav>

      {error && <p className="rounded border border-red-300 bg-red-50 p-3 text-sm text-red-700">{error}</p>}

      {tab === "analytics" && stats && (
        <Section title="Platform analytics" hint="Per product-evaluation.md §6: bookings, GMV, verification & dispute rates.">
          <dl className="grid grid-cols-2 gap-2 text-sm md:grid-cols-4">
            {Object.entries(stats).map(([k, v]) => (
              <div key={k} className="rounded bg-zinc-50 p-3">
                <dt className="text-zinc-500">{k}</dt>
                <dd className="text-lg font-semibold">{String(v)}</dd>
              </div>
            ))}
          </dl>
        </Section>
      )}

      {tab === "verification" && (
        <Section title="Verification Queue" hint="Approve/reject craftsman ID & trade credentials. Sets Verified badge.">
          {rows.map((d) => (
            <div key={String(d.id)} className="mb-2 flex items-center justify-between gap-2 rounded bg-zinc-50 p-2 text-sm">
              <span>
                {String(d.doc_type)} — {String(d.user_id)} — {String(d.status)}
              </span>
              <span className="flex gap-2">
                <button className="rounded border px-2 py-1" onClick={() => void act(`/admin/verification/${d.id}/review`, "POST", { decision: "approved" })}>
                  Approve
                </button>
                <button className="rounded border px-2 py-1" onClick={() => void act(`/admin/verification/${d.id}/review`, "POST", { decision: "rejected" })}>
                  Reject
                </button>
              </span>
            </div>
          ))}
          {rows.length === 0 && !loading && <p className="text-sm text-zinc-500">Queue empty.</p>}
        </Section>
      )}

      {tab === "disputes" && (
        <Section title="Dispute Resolution" hint="Resolve frozen escrow: refund client or release to craftsman.">
          {rows.map((d) => (
            <div key={String(d.id)} className="mb-2 flex items-center justify-between gap-2 rounded bg-zinc-50 p-2 text-sm">
              <span>
                {String(d.id)} — payment {String(d.payment_id)} — {String(d.status)} — {String(d.reason ?? "")}
              </span>
              <span className="flex gap-2">
                <button className="rounded border px-2 py-1" onClick={() => void act(`/admin/disputes/${d.id}/resolve?decision=refund`, "POST")}>
                  Refund
                </button>
                <button className="rounded border px-2 py-1" onClick={() => void act(`/admin/disputes/${d.id}/resolve?decision=release`, "POST")}>
                  Release
                </button>
              </span>
            </div>
          ))}
          {rows.length === 0 && !loading && <p className="text-sm text-zinc-500">No disputes.</p>}
        </Section>
      )}

      {tab === "users" && (
        <Section title="User Management" hint="Suspend / reinstate users. Suspended users get 403 on API.">
          {rows.map((u) => (
            <div key={String(u.id)} className="mb-2 flex items-center justify-between gap-2 rounded bg-zinc-50 p-2 text-sm">
              <span>
                {String(u.phone)} — {String(u.role)} — suspended: {String(u.is_suspended)}
              </span>
              <span className="flex gap-2">
                {u.is_suspended ? (
                  <button className="rounded border px-2 py-1" onClick={() => void act(`/admin/users/${u.id}/reinstate`, "POST")}>
                    Reinstate
                  </button>
                ) : (
                  <button className="rounded border px-2 py-1" onClick={() => void act(`/admin/users/${u.id}/suspend`, "POST", { reason: "admin action" })}>
                    Suspend
                  </button>
                )}
              </span>
            </div>
          ))}
          {rows.length === 0 && !loading && <p className="text-sm text-zinc-500">No users.</p>}
        </Section>
      )}

      {tab === "payouts" && (
        <Section title="Payout Reconciliation" hint="Released payments pending manual disbursement (v1).">
          {rows.map((p) => (
            <div key={String(p.id)} className="mb-2 flex items-center justify-between gap-2 rounded bg-zinc-50 p-2 text-sm">
              <span>
                {String(p.id)} — craftsman {String(p.craftsman_id)} — {String(p.amount)}
              </span>
              <button className="rounded border px-2 py-1" onClick={() => void act(`/admin/payouts/${p.id}/disburse`, "POST")}>
                Mark disbursed
              </button>
            </div>
          ))}
          {rows.length === 0 && !loading && <p className="text-sm text-zinc-500">Nothing pending payout.</p>}
        </Section>
      )}

      {tab === "audit" && (
        <Section title="Audit Log" hint="Every admin action is logged (actor, action, target). Latest 100.">
          {rows.map((l) => (
            <div key={String(l.id)} className="mb-1 rounded bg-zinc-50 p-2 font-mono text-xs">
              {String(l.created_at)} — {String(l.actor_id)} — {String(l.action)} — {String(l.target_type)}/
              {String(l.target_id)}
            </div>
          ))}
          {rows.length === 0 && !loading && <p className="text-sm text-zinc-500">No audit entries.</p>}
        </Section>
      )}
    </main>
  );
}
