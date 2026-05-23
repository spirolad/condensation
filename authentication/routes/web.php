<?php

use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Prometheus metrics endpoint (public)
Route::get('/metrics', [\App\Http\Controllers\MetricsController::class, 'metrics']);

Route::get('/dashboard', function () {
    return redirect(config('app.frontend_url'));
})->middleware(['auth'])->name('dashboard');

Route::get('/auth/logout', function (\Illuminate\Http\Request $request) {
    \Illuminate\Support\Facades\Auth::guard('web')->logout();
    $request->session()->invalidate();
    $request->session()->regenerateToken();
    return redirect(config('app.frontend_url'));
});

// Force re-authentication before starting an OAuth flow.
// Clears any existing web session so skipsAuthorization() cannot silently
// re-use a stale session, then forwards to /oauth/authorize with the original params.
Route::get('/auth/oauth-init', function (\Illuminate\Http\Request $request) {
    \Illuminate\Support\Facades\Auth::guard('web')->logout();
    $request->session()->invalidate();
    $request->session()->regenerateToken();
    return redirect('/oauth/authorize?' . http_build_query($request->query()));
});

Route::middleware('auth')->group(function () {
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');
});

require __DIR__.'/auth.php';
