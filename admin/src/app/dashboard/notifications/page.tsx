"use client";

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

interface Notification {
  id: number;
  title: string;
  message: string;
  is_read: boolean;
  user: {
    name: string;
    email: string;
  } | null;
  created_at: string;
}

export default function NotificationsPage() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [userId, setUserId] = useState(''); // Empty means global
  const [error, setError] = useState('');
  const router = useRouter();

  useEffect(() => {
    fetchNotifications();
  }, []);

  const fetchNotifications = async () => {
    const token = localStorage.getItem('admin_token');
    if (!token) return router.push('/login');

    try {
      const res = await fetch('http://localhost:8000/api/admin/notifications', {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json'
        }
      });
      
      if (res.status === 401 || res.status === 403) {
        localStorage.removeItem('admin_token');
        router.push('/login');
        return;
      }

      if (!res.ok) throw new Error('Failed to fetch notifications');
      const data = await res.json();
      setNotifications(data);
      setError('');
    } catch (err: any) {
      setError(err.message);
    }
  };

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    const token = localStorage.getItem('admin_token');
    try {
      const payload: any = { title, message };
      if (userId) payload.user_id = parseInt(userId);

      const res = await fetch('http://localhost:8000/api/admin/notifications', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json'
        },
        body: JSON.stringify(payload)
      });
      
      if (res.ok) {
        setTitle('');
        setMessage('');
        setUserId('');
        fetchNotifications();
      } else {
        const err = await res.json();
        alert(err.message || 'Failed to send notification');
      }
    } catch (e) {
      alert('Network error');
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Delete this notification?')) return;
    const token = localStorage.getItem('admin_token');
    try {
      await fetch(`http://localhost:8000/api/admin/notifications/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      fetchNotifications();
    } catch (e) {
      alert('Failed to delete');
    }
  };

  return (
    <div>
      <h2 className="text-3xl font-bold text-white mb-8">Push Notifications</h2>
      
      {error && (
        <div className="bg-red-900/40 border border-red-800 text-red-300 p-4 rounded-lg mb-6 flex justify-between items-center">
          <span>Error loading notifications: {error}</span>
          <button 
            onClick={() => { localStorage.removeItem('admin_token'); router.push('/login'); }}
            className="bg-red-800 hover:bg-red-700 text-white text-xs px-3 py-1.5 rounded font-bold"
          >
            Re-login
          </button>
        </div>
      )}
      
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        
        <div className="lg:col-span-2 bg-gray-900 rounded-lg overflow-hidden border border-gray-800">
          <table className="w-full text-left text-gray-300">
            <thead className="bg-gray-800 text-gray-400">
              <tr>
                <th className="px-6 py-4 font-semibold">Title</th>
                <th className="px-6 py-4 font-semibold">Target</th>
                <th className="px-6 py-4 font-semibold">Status</th>
                <th className="px-6 py-4 font-semibold text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-800">
              {notifications.map((notif) => (
                <tr key={notif.id} className="hover:bg-gray-800/50">
                  <td className="px-6 py-4">
                    <div className="font-bold text-white">{notif.title}</div>
                    <div className="text-sm text-gray-500 truncate max-w-[200px]">{notif.message}</div>
                  </td>
                  <td className="px-6 py-4">
                    {notif.user ? (
                      <span className="text-blue-400">User: {notif.user.email}</span>
                    ) : (
                      <span className="text-purple-400 font-bold">Global Broadcast</span>
                    )}
                  </td>
                  <td className="px-6 py-4">
                    <span className={`px-2 py-1 text-xs rounded font-bold ${
                      notif.is_read ? 'bg-gray-500/20 text-gray-400' : 'bg-green-500/20 text-green-400'
                    }`}>
                      {notif.is_read ? 'Read' : 'Unread'}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-right">
                    <button onClick={() => handleDelete(notif.id)} className="text-red-400 hover:text-red-300 font-bold text-sm transition-colors">
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {notifications.length === 0 && <div className="p-8 text-center text-gray-500">No notifications sent yet.</div>}
        </div>

        <div className="bg-gray-900 p-6 rounded-lg border border-gray-800 h-fit">
          <h3 className="text-xl font-bold text-white mb-4">Send Notification</h3>
          <form onSubmit={handleSend}>
            <div className="mb-4">
              <label className="block text-gray-400 text-sm mb-2">Title</label>
              <input type="text" value={title} onChange={e => setTitle(e.target.value)} required className="w-full p-2 bg-gray-800 text-white rounded border border-gray-700 outline-none focus:border-blue-500" />
            </div>
            <div className="mb-4">
              <label className="block text-gray-400 text-sm mb-2">Message</label>
              <textarea value={message} onChange={e => setMessage(e.target.value)} required rows={4} className="w-full p-2 bg-gray-800 text-white rounded border border-gray-700 outline-none focus:border-blue-500"></textarea>
            </div>
            <div className="mb-6">
              <label className="block text-gray-400 text-sm mb-2">Target User ID (Leave empty for Global Broadcast)</label>
              <input type="number" value={userId} onChange={e => setUserId(e.target.value)} className="w-full p-2 bg-gray-800 text-white rounded border border-gray-700 outline-none focus:border-blue-500" placeholder="e.g. 1" />
            </div>
            <button type="submit" className="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 rounded transition-colors">
              Send Alert
            </button>
          </form>
        </div>

      </div>
    </div>
  );
}
