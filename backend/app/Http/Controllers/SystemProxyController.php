<?php

namespace App\Http\Controllers;

use App\Models\SystemProxy;
use App\Services\ProxyEngine;
use Illuminate\Http\Request;

class SystemProxyController extends Controller
{
    public function indexAdmin(Request $request)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);
        return response()->json(SystemProxy::latest()->get());
    }

    public function storeBulk(Request $request)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);
        
        $request->validate(['raw_proxies' => 'required|string']);
        
        $lines = array_filter(array_map('trim', explode("\n", $request->raw_proxies)));
        $created = [];

        foreach ($lines as $line) {
            if (empty($line)) continue;
            $parsed = ProxyEngine::parse($line);
            if ($parsed['host'] && $parsed['port']) {
                $created[] = SystemProxy::create([
                    'ip_address' => $parsed['host'],
                    'port' => (int)$parsed['port'],
                    'username' => $parsed['username'],
                    'password' => $parsed['password'],
                    'status' => 'active',
                ]);
            }
        }

        return response()->json(['message' => count($created) . ' system proxies imported successfully', 'proxies' => $created], 201);
    }

    public function destroy(Request $request, SystemProxy $systemProxy)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);
        $systemProxy->delete();
        return response()->json(null, 204);
    }

    public function purgeDead(Request $request)
    {
        if (!$request->user()->is_admin) return response()->json(['error' => 'Forbidden'], 403);
        $deleted = SystemProxy::where('status', 'dead')->delete();
        return response()->json(['message' => "$deleted dead system proxies purged successfully", 'count' => $deleted]);
    }

    public function indexUser()
    {
        return response()->json(SystemProxy::where('status', 'active')->get());
    }

    public function claim(Request $request, SystemProxy $systemProxy)
    {
        $user = $request->user();
        
        $user->proxies()->create([
            'ip_address' => $systemProxy->ip_address,
            'port' => $systemProxy->port,
            'username' => $systemProxy->username,
            'password' => $systemProxy->password,
            'status' => 'unknown',
        ]);

        return response()->json(['message' => 'Proxy claimed successfully']);
    }
}
