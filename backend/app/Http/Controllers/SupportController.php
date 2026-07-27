<?php

namespace App\Http\Controllers;

use App\Models\SupportConversation;
use App\Models\SupportMessage;
use App\Events\MessageSent;
use Illuminate\Http\Request;
use Kreait\Laravel\Firebase\Facades\Firebase;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification as FirebaseNotification;

class SupportController extends Controller
{
    public function index(Request $request)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);
        
        $conversations = SupportConversation::with('user:id,name,email')
                            ->withCount('messages')
                            ->latest('updated_at')
                            ->get();
        return response()->json($conversations);
    }

    public function show(Request $request, SupportConversation $conversation)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);

        return response()->json($conversation->load('user:id,name,email', 'messages.user:id,name,is_admin'));
    }

    public function reply(Request $request, SupportConversation $conversation)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);

        $request->validate(['message' => 'required|string']);

        $message = SupportMessage::create([
            'support_conversation_id' => $conversation->id,
            'user_id' => $request->user()->id,
            'message' => $request->message
        ]);

        $conversation->touch(); // Update updated_at timestamp

        $message->load('user:id,name,is_admin');
        try {
            broadcast(new MessageSent($message, $conversation->id))->toOthers();
        } catch (\Throwable $e) {
            // Reverb server down or unreachable - message is still saved in DB
        }

        // Send FCM Push Notification to the user if they have an FCM token
        $user = $conversation->user;
        if ($user && $user->fcm_token) {
            try {
                $fcmMessage = CloudMessage::withTarget('token', $user->fcm_token)
                    ->withNotification(FirebaseNotification::create('Support Reply', 'Admin replied to your ticket: ' . $conversation->subject));
                Firebase::messaging()->send($fcmMessage);
            } catch (\Exception $e) {
                // Log exception if needed
            }
        }

        return response()->json($message, 201);
    }

    public function close(Request $request, SupportConversation $conversation)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);
        
        $conversation->update(['status' => 'closed']);
        return response()->json(['message' => 'Ticket closed']);
    }

    public function getTopics(Request $request)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);
        return response()->json(\App\Models\SupportTopic::all());
    }

    public function storeTopic(Request $request)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);
        $request->validate(['name' => 'required|string|max:255']);
        $topic = \App\Models\SupportTopic::create(['name' => $request->name]);
        return response()->json($topic, 201);
    }

    public function deleteTopic(Request $request, \App\Models\SupportTopic $topic)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);
        $topic->delete();
        return response()->json(['message' => 'Topic deleted']);
    }
}
