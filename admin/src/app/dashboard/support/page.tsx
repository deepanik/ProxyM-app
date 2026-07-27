"use client";

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { createEchoClient } from '@/lib/echo';

interface SupportTopic {
  id: number;
  name: string;
}

interface SupportMessage {
  id: number;
  message: string;
  created_at: string;
  user: {
    name: string;
    is_admin: boolean;
  };
}

interface SupportConversation {
  id: number;
  subject: string;
  status: string;
  messages_count: number;
  user: {
    name: string;
    email: string;
  };
  messages?: SupportMessage[];
}

export default function SupportPage() {
  const [conversations, setConversations] = useState<SupportConversation[]>([]);
  const [activeChat, setActiveChat] = useState<SupportConversation | null>(null);
  const [topics, setTopics] = useState<SupportTopic[]>([]);
  const [showTopicsModal, setShowTopicsModal] = useState(false);
  const [newTopicName, setNewTopicName] = useState('');
  const [replyText, setReplyText] = useState('');
  const [error, setError] = useState('');
  const router = useRouter();
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [activeChat?.messages?.length]);

  useEffect(() => {
    fetchConversations();
    fetchTopics();
  }, []);

  const fetchTopics = async () => {
    const token = localStorage.getItem('admin_token');
    if (!token) return;
    try {
      const res = await fetch('http://localhost:8000/api/admin/support-topics', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) setTopics(await res.json());
    } catch (_) {}
  };

  const handleAddTopic = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTopicName.trim()) return;
    const token = localStorage.getItem('admin_token');
    try {
      const res = await fetch('http://localhost:8000/api/admin/support-topics', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ name: newTopicName.trim() })
      });
      if (res.ok) {
        setNewTopicName('');
        fetchTopics();
      }
    } catch (_) {}
  };

  const handleDeleteTopic = async (id: number) => {
    const token = localStorage.getItem('admin_token');
    try {
      const res = await fetch(`http://localhost:8000/api/admin/support-topics/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) fetchTopics();
    } catch (_) {}
  };

  useEffect(() => {
    if (!activeChat) return;
    const token = localStorage.getItem('admin_token');
    if (!token) return;

    const echo = createEchoClient(token);
    const channel = echo.private(`chat.${activeChat.id}`);

    channel.listen('.message.sent', (data: { message: SupportMessage }) => {
      setActiveChat((prev) => {
        if (!prev || prev.id !== activeChat.id) return prev;
        const exists = prev.messages?.some((m) => m.id === data.message.id);
        if (exists) return prev;
        return {
          ...prev,
          messages: [...(prev.messages || []), data.message],
        };
      });
      fetchConversations();
    });

    return () => {
      channel.stopListening('.message.sent');
      echo.disconnect();
    };
  }, [activeChat?.id]);

  const fetchConversations = async () => {
    const token = localStorage.getItem('admin_token');
    if (!token) return router.push('/login');

    try {
      const res = await fetch('http://localhost:8000/api/admin/support', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (!res.ok) throw new Error('Failed to fetch support tickets');
      setConversations(await res.json());
    } catch (err: any) {
      setError(err.message);
    }
  };

  const loadChat = async (id: number) => {
    const token = localStorage.getItem('admin_token');
    try {
      const res = await fetch(`http://localhost:8000/api/admin/support/${id}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      setActiveChat(await res.json());
    } catch (err) {
      alert('Failed to load chat');
    }
  };

  const handleReply = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!activeChat) return;

    const token = localStorage.getItem('admin_token');
    try {
      const res = await fetch(`http://localhost:8000/api/admin/support/${activeChat.id}/reply`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ message: replyText })
      });
      
      if (res.ok) {
        setReplyText('');
        loadChat(activeChat.id);
        fetchConversations();
      }
    } catch (e) {
      alert('Network error');
    }
  };

  const closeTicket = async (id: number) => {
    if (!confirm('Close this ticket?')) return;
    const token = localStorage.getItem('admin_token');
    try {
      await fetch(`http://localhost:8000/api/admin/support/${id}/close`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      fetchConversations();
      if (activeChat?.id === id) setActiveChat({ ...activeChat, status: 'closed' });
    } catch (e) {
      alert('Failed to close ticket');
    }
  };

  if (error) return <div className="text-red-500">Error: {error}</div>;

  return (
    <div className="h-full flex flex-col">
      <div className="flex justify-between items-center mb-8">
        <h2 className="text-3xl font-bold text-white">Support Tickets</h2>
        <button
          onClick={() => setShowTopicsModal(true)}
          className="bg-blue-600 hover:bg-blue-700 text-white font-bold px-4 py-2 rounded transition-colors text-sm"
        >
          Manage Subject Topics ({topics.length})
        </button>
      </div>
      
      <div className="flex-1 grid grid-cols-1 lg:grid-cols-3 gap-8 min-h-0">
        
        {/* Ticket List */}
        <div className="lg:col-span-1 bg-gray-900 rounded-lg overflow-y-auto border border-gray-800">
          <div className="divide-y divide-gray-800">
            {conversations.map((conv) => (
              <div 
                key={conv.id} 
                onClick={() => loadChat(conv.id)}
                className={`p-4 cursor-pointer transition-colors hover:bg-gray-800 ${
                  activeChat?.id === conv.id ? 'bg-gray-800 border-l-4 border-blue-500' : ''
                }`}
              >
                <div className="flex justify-between items-start mb-1">
                  <div className="font-bold text-white truncate pr-2">{conv.subject}</div>
                  <span className={`px-2 py-0.5 text-xs rounded font-bold ${
                    conv.status === 'open' ? 'bg-green-500/20 text-green-400' : 'bg-gray-500/20 text-gray-400'
                  }`}>
                    {conv.status}
                  </span>
                </div>
                <div className="text-sm text-gray-400 mb-1">{conv.user.email}</div>
                <div className="text-xs text-gray-500">{conv.messages_count} messages</div>
              </div>
            ))}
            {conversations.length === 0 && <div className="p-8 text-center text-gray-500">No support tickets found.</div>}
          </div>
        </div>

        {/* Chat Window */}
        <div className="lg:col-span-2 bg-gray-900 rounded-lg border border-gray-800 flex flex-col overflow-hidden">
          {activeChat ? (
            <>
              {/* Chat Header */}
              <div className="p-4 bg-gray-800 border-b border-gray-700 flex justify-between items-center">
                <div>
                  <h3 className="font-bold text-white">{activeChat.subject}</h3>
                  <div className="text-sm text-gray-400">User: {activeChat.user.email}</div>
                </div>
                {activeChat.status === 'open' && (
                  <button onClick={() => closeTicket(activeChat.id)} className="bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded text-sm transition-colors">
                    Close Ticket
                  </button>
                )}
              </div>

              {/* Chat Messages */}
              <div className="flex-1 p-4 overflow-y-auto space-y-4">
                {activeChat.messages?.map((msg) => (
                  <div key={msg.id} className={`flex ${msg.user.is_admin ? 'justify-end' : 'justify-start'}`}>
                    <div className={`max-w-[70%] p-3 rounded-lg ${
                      msg.user.is_admin ? 'bg-blue-600 text-white rounded-br-none' : 'bg-gray-700 text-white rounded-bl-none'
                    }`}>
                      <div className="text-xs font-bold opacity-75 mb-1">{msg.user.name}</div>
                      <div>{msg.message}</div>
                    </div>
                  </div>
                ))}
                <div ref={messagesEndRef} />
              </div>

              {/* Chat Input */}
              {activeChat.status === 'open' ? (
                <form onSubmit={handleReply} className="p-4 bg-gray-800 border-t border-gray-700 flex gap-2">
                  <input
                    type="text"
                    value={replyText}
                    onChange={e => setReplyText(e.target.value)}
                    required
                    placeholder="Type your response..."
                    className="flex-1 p-2 bg-gray-700 text-white rounded border border-gray-600 outline-none focus:border-blue-500"
                  />
                  <button type="submit" className="bg-blue-600 hover:bg-blue-700 px-6 py-2 text-white font-bold rounded transition-colors">
                    Send
                  </button>
                </form>
              ) : (
                <div className="p-4 bg-gray-800 border-t border-gray-700 text-center text-gray-500 italic">
                  This ticket has been closed.
                </div>
              )}
            </>
          ) : (
            <div className="flex-1 flex items-center justify-center text-gray-500">
              Select a ticket to view the conversation.
            </div>
          )}
        </div>

      </div>

      {/* Topics Management Modal */}
      {showTopicsModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50">
          <div className="bg-gray-900 border border-gray-800 rounded-lg p-6 w-full max-w-md">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-xl font-bold text-white">Manage Subject Topics</h3>
              <button onClick={() => setShowTopicsModal(false)} className="text-gray-400 hover:text-white">✕</button>
            </div>
            
            <form onSubmit={handleAddTopic} className="flex gap-2 mb-6">
              <input
                type="text"
                value={newTopicName}
                onChange={(e) => setNewTopicName(e.target.value)}
                placeholder="New topic name..."
                required
                className="flex-1 p-2 bg-gray-800 border border-gray-700 text-white rounded outline-none focus:border-blue-500 text-sm"
              />
              <button type="submit" className="bg-green-600 hover:bg-green-700 text-white font-bold px-4 py-2 rounded text-sm transition-colors">
                Add
              </button>
            </form>

            <div className="max-h-60 overflow-y-auto divide-y divide-gray-800">
              {topics.map((t) => (
                <div key={t.id} className="py-2.5 flex justify-between items-center text-sm text-gray-200">
                  <span>{t.name}</span>
                  <button
                    onClick={() => handleDeleteTopic(t.id)}
                    className="text-red-400 hover:text-red-300 text-xs font-bold bg-red-500/10 hover:bg-red-500/20 px-2 py-1 rounded transition-colors"
                  >
                    Delete
                  </button>
                </div>
              ))}
              {topics.length === 0 && <div className="text-gray-500 text-center py-4 text-sm">No custom topics found.</div>}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
