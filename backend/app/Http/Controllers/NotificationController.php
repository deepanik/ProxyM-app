<?php

namespace App\Http\Controllers;

use App\Models\Notification;
use App\Models\User;
use App\Events\NotificationSent;
use Illuminate\Http\Request;
use Kreait\Laravel\Firebase\Facades\Firebase;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification as FirebaseNotification;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);
        
        // Admin sees all notifications
        return response()->json(Notification::with('user:id,name,email')->latest()->get());
    }

    public function store(Request $request)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);

        $request->validate([
            'title' => 'required|string|max:255',
            'message' => 'required|string',
            'user_id' => 'nullable|exists:users,id'
        ]);

        $notification = Notification::create([
            'title' => $request->title,
            'message' => $request->message,
            'user_id' => $request->user_id, // If null, it's global
        ]);

        if ($notification->user_id) {
            broadcast(new NotificationSent($notification, $notification->user_id))->toOthers();
            
            $user = User::find($notification->user_id);
            if ($user && $user->fcm_token) {
                try {
                    $fcmMessage = CloudMessage::withTarget('token', $user->fcm_token)
                        ->withNotification(FirebaseNotification::create($notification->title, $notification->message));
                    Firebase::messaging()->send($fcmMessage);
                } catch (\Exception $e) {}
            }
        } else {
            // Global notification
            $users = User::whereNotNull('fcm_token')->get();
            foreach ($users as $user) {
                broadcast(new NotificationSent($notification, $user->id))->toOthers();
                try {
                    $fcmMessage = CloudMessage::withTarget('token', $user->fcm_token)
                        ->withNotification(FirebaseNotification::create($notification->title, $notification->message));
                    Firebase::messaging()->send($fcmMessage);
                } catch (\Exception $e) {}
            }
        }

        return response()->json($notification, 201);
    }

    public function destroy(Request $request, Notification $notification)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);
        
        $notification->delete();
        return response()->json(['message' => 'Notification deleted']);
    }
}
