<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use App\Models\SupportConversation;
use App\Models\SupportMessage;
use App\Events\MessageSent;
use Illuminate\Http\Request;
use Kreait\Laravel\Firebase\Facades\Firebase;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification as FirebaseNotification;

class UserCommunicationController extends Controller
{
    public function getNotifications(Request $request)
    {
        $userId = $request->user()->id;
        $notifications = Notification::whereNull('user_id')
                            ->orWhere('user_id', $userId)
                            ->latest()
                            ->get();
        return response()->json($notifications);
    }

    public function markNotificationRead(Request $request, Notification $notification)
    {
        if ($notification->user_id !== null && $notification->user_id !== $request->user()->id) {
            return response()->json(['error' => 'Forbidden'], 403);
        }
        $notification->update(['is_read' => true]);
        return response()->json(['message' => 'Marked as read']);
    }

    public function getSupportTickets(Request $request)
    {
        $conversations = SupportConversation::where('user_id', $request->user()->id)
                            ->withCount('messages')
                            ->latest('updated_at')
                            ->get();
        return response()->json($conversations);
    }

    public function createSupportTicket(Request $request)
    {
        $request->validate([
            'subject' => 'required|string|max:255',
            'message' => 'required|string'
        ]);

        $conversation = SupportConversation::create([
            'user_id' => $request->user()->id,
            'subject' => $request->subject,
            'status' => 'open'
        ]);

        SupportMessage::create([
            'support_conversation_id' => $conversation->id,
            'user_id' => $request->user()->id,
            'message' => $request->message
        ]);

        return response()->json($conversation, 201);
    }

    public function getSupportChat(Request $request, SupportConversation $conversation)
    {
        if ($conversation->user_id !== $request->user()->id) {
            return response()->json(['error' => 'Forbidden'], 403);
        }

        return response()->json($conversation->load('messages.user:id,name,is_admin'));
    }

    public function replySupportChat(Request $request, SupportConversation $conversation)
    {
        if ($conversation->user_id !== $request->user()->id) {
            return response()->json(['error' => 'Forbidden'], 403);
        }

        if ($conversation->status !== 'open') {
            return response()->json(['error' => 'Ticket is closed'], 400);
        }

        $request->validate(['message' => 'required|string']);

        $message = SupportMessage::create([
            'support_conversation_id' => $conversation->id,
            'user_id' => $request->user()->id,
            'message' => $request->message
        ]);

        $conversation->touch();

        $message->load('user:id,name,is_admin');
        try {
            broadcast(new MessageSent($message, $conversation->id))->toOthers();
        } catch (\Throwable $e) {
            // Reverb server down or unreachable - message is still saved in DB
        }

        return response()->json($message, 201);
    }

    public function getSupportTopics()
    {
        return response()->json(\App\Models\SupportTopic::pluck('name'));
    }
}
