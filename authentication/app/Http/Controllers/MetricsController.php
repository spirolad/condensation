<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class MetricsController
{
    public function metrics(Request $request)
    {
        $lines = [];
        $lines[] = "# HELP auth_up If the auth service is up";
        $lines[] = "# TYPE auth_up gauge";
        $lines[] = "auth_up 1";
        $lines[] = "# HELP auth_requests_total Total HTTP requests (best-effort)";
        $lines[] = "# TYPE auth_requests_total counter";
        $method = $request->method();
        $path = $request->path();
        $esc = function ($v) {
            return str_replace(['\\', '"'], ['\\\\', '\\"'], $v);
        };
        $lines[] = sprintf('auth_requests_total{method="%s",path="%s"} 1', $esc($method), $esc($path));

        $body = implode("\n", $lines) . "\n";
        return response($body, 200)
            ->header('Content-Type', 'text/plain; version=0.0.4; charset=utf-8');
    }
}

