<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProxyController;
use App\Http\Controllers\ProxyGroupController;
use App\Http\Controllers\AdminController;
use App\Http\Controllers\PlanController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\SupportController;
use App\Http\Controllers\UserCommunicationController;
use App\Http\Controllers\SubscriptionController;
use App\Http\Controllers\SystemProxyController;

Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:6,1');
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:6,1');

Route::middleware(['auth:sanctum', 'throttle:api'])->group(function () {
    Broadcast::routes();

    Route::get('/user', function (Request $request) {
        return $request->user();
    });

    Route::post('proxies/{proxy}/test', [ProxyController::class, 'test']);
    Route::apiResource('proxies', ProxyController::class);
    Route::apiResource('proxy-groups', ProxyGroupController::class);

    // Public / System Proxies (User Endpoints)
    Route::get('/public-proxies', [SystemProxyController::class, 'indexUser']);
    Route::post('/public-proxies/{systemProxy}/claim', [SystemProxyController::class, 'claim']);

    // User Communication
    Route::get('/notifications', [UserCommunicationController::class, 'getNotifications']);
    Route::post('/notifications/{notification}/read', [UserCommunicationController::class, 'markNotificationRead']);
    
    Route::get('/support-topics', [UserCommunicationController::class, 'getSupportTopics']);
    Route::get('/support', [UserCommunicationController::class, 'getSupportTickets']);
    Route::post('/support', [UserCommunicationController::class, 'createSupportTicket']);
    Route::get('/support/{conversation}', [UserCommunicationController::class, 'getSupportChat']);
    Route::post('/support/{conversation}/reply', [UserCommunicationController::class, 'replySupportChat']);

    // Subscriptions
    Route::get('/plans', [SubscriptionController::class, 'getPlans']);
    Route::post('/subscribe', [SubscriptionController::class, 'subscribe']);

    // Admin routes
    Route::get('/admin/stats', [AdminController::class, 'stats']);
    Route::get('/admin/users', [AdminController::class, 'getUsers']);
    Route::post('/admin/users/{user}/block', [AdminController::class, 'toggleBlockUser']);
    Route::get('/admin/proxies', [AdminController::class, 'getProxies']);
    Route::delete('/admin/proxies/purge-dead', [AdminController::class, 'purgeDeadProxies']);
    
    // Admin System Proxies Management
    Route::get('/admin/system-proxies', [SystemProxyController::class, 'indexAdmin']);
    Route::post('/admin/system-proxies', [SystemProxyController::class, 'storeBulk']);
    Route::delete('/admin/system-proxies/purge-dead', [SystemProxyController::class, 'purgeDead']);
    Route::delete('/admin/system-proxies/{systemProxy}', [SystemProxyController::class, 'destroy']);

    Route::get('/admin/plans', [PlanController::class, 'index']);
    Route::post('/admin/plans', [PlanController::class, 'store']);
    Route::delete('/admin/plans/{plan}', [PlanController::class, 'destroy']);
    
    Route::get('/admin/notifications', [NotificationController::class, 'index']);
    Route::post('/admin/notifications', [NotificationController::class, 'store']);
    Route::delete('/admin/notifications/{notification}', [NotificationController::class, 'destroy']);

    Route::get('/admin/support-topics', [SupportController::class, 'getTopics']);
    Route::post('/admin/support-topics', [SupportController::class, 'storeTopic']);
    Route::delete('/admin/support-topics/{topic}', [SupportController::class, 'deleteTopic']);

    Route::get('/admin/support', [SupportController::class, 'index']);
    Route::get('/admin/support/{conversation}', [SupportController::class, 'show']);
    Route::post('/admin/support/{conversation}/reply', [SupportController::class, 'reply']);
    Route::post('/admin/support/{conversation}/close', [SupportController::class, 'close']);
});
