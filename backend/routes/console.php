<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

use Illuminate\Support\Facades\Schedule;
use App\Models\Proxy;
use App\Models\SystemProxy;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Auto-delete dead proxies daily
Schedule::call(function () {
    Proxy::where('status', 'dead')->delete();
    SystemProxy::where('status', 'dead')->delete();
})->daily();
