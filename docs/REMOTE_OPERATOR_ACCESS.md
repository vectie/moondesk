# Controlled remote operator access

MoonDesk is a privileged shared desktop, not a tenant-isolated public workspace.
Putting a TCP forwarder in front of its local HTTP port does not authenticate
users. Never expose the local-only mode through an unauthenticated forwarder.

Set these server-side values before exposing a remote operator instance:

```text
MOONDESK_ALLOWED_HOSTS=106.39.18.146:5001,192.168.2.175:5001
MOONDESK_PUBLIC_SCHEME=http
MOONDESK_IDENTITY_ENDPOINT=http://127.0.0.1:5003
MOONDESK_IDENTITY_HOST=106.39.18.146:5003
```

Allowed hosts are exact authorities including the port, not wildcard patterns.
Public mode is enabled whenever ALLOWED_HOSTS is nonempty. In this mode every
desktop/API request requires a LunaNexa cookie session whose authoritative
account is Active and has PlatformOperator. This includes requests with a
loopback Host header: a TCP proxy cannot turn a remote caller into a trusted
local operator. Only the minimal health response (`ok`, `service`) is public.

The root page presents a username/password login. The server forwards the
credentials to the configured identity service with operator audience, checks
the resulting account role, and returns only HttpOnly cookies. Session bearer
tokens are never returned by this login endpoint. Missing identity settings,
invalid sessions, oversized responses, timeouts, and disabled/non-operator
accounts deny access. Revocation is checked on every protected request.

All write methods require an exact same-origin Origin header; missing Origin
is not a bypass, including for local scripts. Cross-origin read requests with
an Origin header are also denied. The scheme defaults to HTTP because the
native server is HTTP; configure HTTPS only behind a correctly configured TLS
edge. Plain HTTP does not protect credentials on the client-to-edge network.

Local desktop mode (empty ALLOWED_HOSTS) retains loopback authority checks and
does not require the platform identity service. It must remain local-only.
Host and Origin checks are rebinding/CSRF defenses, not authentication.

Acceptance must check: anonymous and forged-cookie requests denied; spoofed
loopback Host cannot bypass public auth; cross-origin and no-Origin writes
denied; a real active operator can load the desktop; non-operators cannot;
health does not disclose filesystem paths; identity outage fails closed.
