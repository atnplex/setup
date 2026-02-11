# R85: Verification of Public Endpoints

> **Authority**: OPERATIONAL RULE
> **Severity**: HIGH - Prevents false positive verification
> **Created**: 2026-02-05

---

## Core Principle

> [!CAUTION]
> **NEVER** rely solely on remote HTTP status codes (e.g., 200, 302) to verify service health without confirming backend reachability.

Cloudflare, load balancers, and reverse proxies often return valid HTTP responses (redirects, maintenance pages) even when the backend is down.

## Verification Standard

When verifying a public endpoint:

1. **Verify Backend First**: Confirm the service is running and accessible locally (e.g., `curl localhost:port`).
2. **Verify Tunnel/Proxy**: Check logs of the ingress service (`cloudflared`, `caddy`, `nginx`) for successful upstream connections.
3. **Verify Public Reachability**:
    * Use a browser or external `curl`.
    * **CRITICAL**: If you receive a redirect (301/302), you MUST follow it or inspect the location to ensure it's not an error page or infinite loop.
    * **CRITICAL**: "Connection Timed Out" (522/524) means the edge cannot reach the origin.
4. **Triangulate**: If public access fails, verify intermediate layers (Tailscale IP, LAN IP) to isolate the failure domain.

## Example

❌ **Incorrect**:
"curl returned 302, so the site is up." (Might be an auth redirect loop or edge policy while backend is down).

✅ **Correct**:

1. `curl localhost:8080` -> HTTP 200 OK (Backend is up).
2. `curl https://public.url` -> HTTP 302 (Redirect to Auth).
3. "Service is running locally and reachable via public URL (redirecting to auth)."
