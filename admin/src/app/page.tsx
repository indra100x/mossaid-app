export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-8">
      <h1 className="text-3xl font-bold">Mossaid Admin</h1>
      <p className="mt-2 text-zinc-600">Admin dashboard skeleton — ready for Phase 3</p>
      <div className="mt-8 grid grid-cols-2 gap-4 text-sm">
        <div className="rounded border p-4">
          <h2 className="font-semibold">Verification Queue</h2>
          <p className="text-zinc-500">Placeholder</p>
        </div>
        <div className="rounded border p-4">
          <h2 className="font-semibold">Dispute Resolution</h2>
          <p className="text-zinc-500">Placeholder</p>
        </div>
        <div className="rounded border p-4">
          <h2 className="font-semibold">User Management</h2>
          <p className="text-zinc-500">Placeholder</p>
        </div>
        <div className="rounded border p-4">
          <h2 className="font-semibold">Analytics</h2>
          <p className="text-zinc-500">Placeholder</p>
        </div>
      </div>
    </main>
  );
}
