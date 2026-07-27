"use client";

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

interface SystemProxy {
  id: number;
  ip_address: string;
  port: number;
  username?: string;
  password?: string;
  protocol: string;
  status: string;
  created_at: string;
}

export default function SystemProxiesPage() {
  const [proxies, setProxies] = useState<SystemProxy[]>([]);
  const [rawProxies, setRawProxies] = useState('');
  const [loading, setLoading] = useState(true);
  const [importing, setImporting] = useState(false);
  const [message, setMessage] = useState('');
  const router = useRouter();

  const token = typeof window !== 'undefined' ? localStorage.getItem('admin_token') : null;

  const fetchProxies = async () => {
    if (!token) {
      router.push('/login');
      return;
    }
    try {
      const res = await fetch('http://localhost:8000/api/admin/system-proxies', {
        headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' }
      });
      if (res.ok) {
        const data = await res.json();
        setProxies(data);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchProxies();
  }, []);

  const handleBulkImport = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!rawProxies.trim()) return;

    setImporting(true);
    setMessage('');

    try {
      const res = await fetch('http://localhost:8000/api/admin/system-proxies', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({ raw_proxies: rawProxies })
      });

      const data = await res.json();
      if (res.ok) {
        setMessage(data.message || 'Proxies imported successfully!');
        setRawProxies('');
        fetchProxies();
      } else {
        setMessage(data.error || 'Import failed');
      }
    } catch (err) {
      setMessage('Network error during import');
    } finally {
      setImporting(false);
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Are you sure you want to delete this system proxy?')) return;
    try {
      const res = await fetch(`http://localhost:8000/api/admin/system-proxies/${id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' }
      });
      if (res.ok) {
        setProxies(proxies.filter(p => p.id !== id));
      }
    } catch (e) {
      console.error(e);
    }
  };

  const handlePurgeDead = async () => {
    if (!confirm('Are you sure you want to purge all dead system proxies?')) return;
    try {
      const res = await fetch('http://localhost:8000/api/admin/system-proxies/purge-dead', {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' }
      });
      if (res.ok) {
        const data = await res.json();
        setMessage(data.message);
        fetchProxies();
      }
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-8">
        <div>
          <h2 className="text-3xl font-bold text-white">System / Free Proxies</h2>
          <p className="text-gray-400 text-sm mt-1">Manage global proxies available for app users to claim.</p>
        </div>
        <div className="flex items-center gap-4">
          <button
            onClick={handlePurgeDead}
            className="bg-red-950/60 hover:bg-red-900/80 text-red-400 border border-red-800 px-4 py-2 rounded-lg font-semibold text-sm transition-colors"
          >
            Purge Dead Proxies
          </button>
          <span className="bg-blue-900/50 text-blue-400 border border-blue-800 px-4 py-2 rounded-lg font-bold">
            Total: {proxies.length}
          </span>
        </div>
      </div>

      {/* Bulk Add Section */}
      <div className="bg-gray-900 border border-gray-800 rounded-lg p-6 mb-8">
        <h3 className="text-xl font-bold text-white mb-3">Bulk Add System Proxies</h3>
        <p className="text-gray-400 text-sm mb-4">Paste proxy strings one per line (Supported formats: <code className="text-blue-400">IP:PORT</code> or <code className="text-blue-400">IP:PORT:USERNAME:PASSWORD</code>)</p>

        <form onSubmit={handleBulkImport}>
          <textarea
            rows={5}
            placeholder="192.168.1.1:8080&#10;10.0.0.1:3128:admin:secret"
            value={rawProxies}
            onChange={(e) => setRawProxies(e.target.value)}
            className="w-full p-4 bg-gray-950 text-gray-200 border border-gray-800 rounded-lg focus:border-blue-500 outline-none font-mono text-sm mb-4"
          />

          {message && (
            <div className={`p-3 rounded mb-4 text-sm ${message.includes('success') ? 'bg-green-900/40 text-green-300 border border-green-800' : 'bg-red-900/40 text-red-300 border border-red-800'}`}>
              {message}
            </div>
          )}

          <button
            type="submit"
            disabled={importing || !rawProxies.trim()}
            className="bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white font-semibold px-6 py-2.5 rounded-lg transition-colors"
          >
            {importing ? 'Importing...' : 'Add System Proxies'}
          </button>
        </form>
      </div>

      {/* Proxy Table */}
      <div className="bg-gray-900 border border-gray-800 rounded-lg overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-gray-400">Loading system proxies...</div>
        ) : proxies.length === 0 ? (
          <div className="p-8 text-center text-gray-500">No system proxies added yet.</div>
        ) : (
          <table className="w-full text-left border-collapse text-sm">
            <thead>
              <tr className="bg-gray-950 border-b border-gray-800 text-gray-400 uppercase text-xs">
                <th className="p-4">IP Address</th>
                <th className="p-4">Port</th>
                <th className="p-4">Auth</th>
                <th className="p-4">Status</th>
                <th className="p-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-800 text-gray-300">
              {proxies.map(p => (
                <tr key={p.id} className="hover:bg-gray-800/50">
                  <td className="p-4 font-mono font-medium text-white">{p.ip_address}</td>
                  <td className="p-4 font-mono">{p.port}</td>
                  <td className="p-4">
                    {p.username ? (
                      <span className="text-gray-400 font-mono text-xs">{p.username}:{p.password}</span>
                    ) : (
                      <span className="text-gray-600 italic">None</span>
                    )}
                  </td>
                  <td className="p-4">
                    <span className="px-2.5 py-1 text-xs rounded-full bg-green-950 text-green-400 border border-green-800 font-medium">
                      {p.status}
                    </span>
                  </td>
                  <td className="p-4 text-right">
                    <button
                      onClick={() => handleDelete(p.id)}
                      className="text-red-400 hover:text-red-300 bg-red-950/40 hover:bg-red-900/60 border border-red-800/60 px-3 py-1.5 rounded transition-colors text-xs"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
