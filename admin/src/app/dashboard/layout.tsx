"use client";

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen bg-gray-950">
      <aside className="w-64 bg-gray-900 border-r border-gray-800 p-6 flex flex-col">
        <h1 className="text-2xl font-bold text-white mb-8">ProxyM Admin</h1>
        <nav className="flex-1 space-y-2">
          <a href="/dashboard" className="block text-gray-300 hover:text-white px-4 py-2 rounded bg-gray-800">Dashboard</a>
          <a href="/dashboard/system-proxies" className="block text-gray-400 hover:text-white hover:bg-gray-800 px-4 py-2 rounded transition-colors">System Proxies (Free)</a>
          <a href="/dashboard/users" className="block text-gray-400 hover:text-white hover:bg-gray-800 px-4 py-2 rounded transition-colors">Users</a>
          <a href="/dashboard/proxies" className="block text-gray-400 hover:text-white hover:bg-gray-800 px-4 py-2 rounded transition-colors">Proxies</a>
          <a href="/dashboard/plans" className="block text-gray-400 hover:text-white hover:bg-gray-800 px-4 py-2 rounded transition-colors">Plans</a>
          <a href="/dashboard/notifications" className="block text-gray-400 hover:text-white hover:bg-gray-800 px-4 py-2 rounded transition-colors">Notifications</a>
          <a href="/dashboard/support" className="block text-gray-400 hover:text-white hover:bg-gray-800 px-4 py-2 rounded transition-colors">Support Chat</a>
        </nav>
        <button 
          onClick={() => { localStorage.removeItem('admin_token'); window.location.href='/login'; }}
          className="text-gray-400 hover:text-red-400 text-left px-4 py-2"
        >
          Logout
        </button>
      </aside>
      <main className="flex-1 p-8 overflow-y-auto">
        {children}
      </main>
    </div>
  );
}
