import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

const AUTH_URL =
  process.env.API_URL ?? process.env.AUTH_URL ?? "http://localhost:8000";

/**
 * Proactive token refresh at the edge. When the browser has lost its
 * access_token (e.g. the cookie maxAge elapsed) but still holds a valid
 * refresh_token, we refresh here so that downstream Server Components
 * and Route Handlers see a fresh session. Middleware can write cookies
 * via NextResponse, and Passport's refresh_token rotation is safely
 * persisted.
 *
 * This does NOT call /api/user to validate still-present tokens — doing
 * so would add an HTTP round-trip to every request. Stale-but-present
 * tokens are handled downstream:
 *   - Route Handlers: adminProxy retries once on 401 via refreshAccessToken.
 *   - Server Components: `resolveAdminAuth` returns `needs_refresh`,
 *     which the admin layout translates into a redirect to
 *     /api/auth/refresh-redirect.
 */
export async function middleware(req: NextRequest) {
  const accessToken = req.cookies.get("access_token")?.value;
  const refreshToken = req.cookies.get("refresh_token")?.value;

  // Always expose the request pathname + search to downstream Server
  // Components so they can build accurate redirect URLs (e.g. the admin
  // layout redirecting to /api/auth/refresh-redirect?return=<here>).
  const pathnameWithSearch =
    req.nextUrl.pathname + (req.nextUrl.search ?? "");

  if (accessToken || !refreshToken) {
    const passthrough = new Headers(req.headers);
    passthrough.set("x-pathname", pathnameWithSearch);
    try {
      const { getRequestCounter } = await import('./lib/metrics');
      const counter = getRequestCounter();
      if (counter) counter.inc();
    } catch (e) {
    }
    return NextResponse.next({ request: { headers: passthrough } });
  }

  let tokenRes: Response;
  try {
    tokenRes = await fetch(`${AUTH_URL}/oauth/token`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        grant_type: "refresh_token",
        refresh_token: refreshToken,
        client_id: process.env.CLIENT_ID,
      }),
      cache: "no-store",
    });
  } catch {
    return NextResponse.next();
  }

  if (!tokenRes.ok) {
    const response = NextResponse.next();
    // Only clear the refresh_token on a definitive 4xx (expired /
    // revoked). On 5xx, leave it so a later retry can recover.
    if (tokenRes.status < 500) {
      response.cookies.delete("refresh_token");
    }
    return response;
  }

  const tokens = (await tokenRes.json().catch(() => null)) as
    | { access_token?: string; refresh_token?: string; expires_in?: number }
    | null;
  if (!tokens?.access_token) return NextResponse.next();

  // Rewrite the incoming request's Cookie header so Server Components /
  // Route Handlers reading cookies during this same request see the new
  // access_token without needing another round-trip.
  const requestHeaders = new Headers(req.headers);
  requestHeaders.set("x-pathname", pathnameWithSearch);
  const cookieParts = req.cookies
    .getAll()
    .filter((c) => c.name !== "access_token" && c.name !== "refresh_token")
    .map((c) => `${c.name}=${c.value}`);
  cookieParts.push(`access_token=${tokens.access_token}`);
  if (tokens.refresh_token) {
    cookieParts.push(`refresh_token=${tokens.refresh_token}`);
  } else {
    cookieParts.push(`refresh_token=${refreshToken}`);
  }
  requestHeaders.set("cookie", cookieParts.join("; "));

  const response = NextResponse.next({ request: { headers: requestHeaders } });
  response.cookies.set("access_token", tokens.access_token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: tokens.expires_in,
    sameSite: "lax",
  });
  if (tokens.refresh_token) {
    response.cookies.set("refresh_token", tokens.refresh_token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      path: "/",
      maxAge: 60 * 60 * 24 * 30,
      sameSite: "lax",
    });
  }
  return response;
}

export const config = {
  matcher: [
    // Match every application route except static assets, Next.js
    // internals, and the token endpoints themselves (which must not be
    // wrapped in refresh logic).
    "/((?!_next/static|_next/image|favicon.ico|api/auth/refresh|api/auth/refresh-redirect|api/auth/callback|api/auth/login|api/auth/logout).*)",
  ],
};
