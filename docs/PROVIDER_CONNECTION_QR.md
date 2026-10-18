# Import an OpenAI connection

Open **Settings → Scan connection QR** (also in Code assistance).
Use the camera, choose a QR image, or expand **Paste connection settings**.
Review the service URL and model, then choose **Connect**. MoonDesk sends the
descriptor through authenticated MoonClaw control. MoonClaw asks MoonGate to
validate the unsaved connection before saving and activating the provider.
Failed validation saves nothing and leaves the current provider and binding
unchanged. Validation does not run inference.
QR images are decoded locally. The key is masked in the review and cleared
from the dialog on close; MoonGate stores it as provider configuration.

The generic UTF-8 JSON format is:

```json
{
  "version": "openai.connection.v1",
  "api": "chat.completions",
  "base_url": "https://example.invalid/v1",
  "api_key": "YOUR_PRIVATE_SECRET",
  "model": "MODEL_ID",
  "max_output_tokens": 16384
}
```

`max_output_tokens` is the recommended client output budget. The current
MoonGate provider contract does not set a per-provider generation limit;
the model service and requesting runtime enforce their own limits.
The base URL must use HTTPS for remote services; HTTP is allowed only for
loopback. No credentials, query string or fragment may appear in the URL.
The descriptor is private: do not publish it, log it, or send it to a QR
generation website. Other clients can implement the same versioned format.

The signed-in LunaNexa MaaS page generates this format after the user chooses
a saved API key. MoonDesk does not
depend on LunaNexa code or install application code on managed GPU nodes.

## Hosted runtime requirements

Use `deploy/package-hosted-connection.mbtx` on the Linux amd64 build host to
overlay a reviewed native binary and hosted UI onto the current OCI image.
It includes the dynamically loaded OpenSSL libraries and system CA bundle;
`ldd` on the executable alone does not discover this HTTPS requirement.
Certificate verification remains enabled. Preserve the base image's DNS
libraries, gateway/runtime executables, entrypoint and user configuration.

MoonClaw must be running with its private control configuration available to
MoonDesk. The import uses `POST /v1/provider-connections/import` with the same
descriptor, execution token and instance binding as other private control
operations. MoonDesk does not contact the provider or bootstrap MoonGate.
MoonClaw uses the configured MoonGate control credential and its existing
same-origin loopback bootstrap when needed; it never bootstraps a remote
service or returns the token to the UI.
After successful transient validation, the import creates or updates the
provider in MoonGate's `openclaw` routing group, activates it and binds the
`moondesk` application. The public import response remains
`{ok:true,status:"connected",model,provider_id}`. Candidate keys and upstream
error bodies are not returned in errors.

An isolated workspace also needs operator approval for the model endpoint's
exact destination address and TCP port. Keep that approval in a narrowly
selected supplemental egress policy; preserve controller-owned isolation rules.
Do not open unrestricted Internet, Kubernetes API, node metadata or GPU access
to make a provider connection succeed. DNS/address changes require a reviewed
policy update.
