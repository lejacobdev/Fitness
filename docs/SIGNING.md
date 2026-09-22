# Signing without a Mac

`testflight.yml` needs five secrets and one variable. Everything below can be
produced from Linux — §19 notes that a keychain *export* can never work
unattended, because `security export` blocks on a GUI dialog, so the certificate
is built from an `openssl` CSR instead.

**Never paste any of these values into a chat, an issue or a commit.** Every
command below pipes from a file or stdin so the value does not land in shell
history or a transcript.

## What the workflows read

| Name | Kind | What it is |
|---|---|---|
| `APPLE_TEAM_ID` | repo **variable** | The 10-character team id. Not secret, but wrong values fail confusingly |
| `ASC_KEY_ID` | secret | App Store Connect API key id, 10 characters |
| `ASC_ISSUER_ID` | secret | The issuer UUID, shown once at the top of the Keys tab |
| `ASC_PRIVATE_KEY` | secret | The whole `AuthKey_XXXXXXXXXX.p8` file, including both BEGIN/END lines |
| `APPLE_DIST_CERT_P12_BASE64` | secret | The distribution certificate and its private key, as base64 of a `.p12` |
| `APPLE_DIST_CERT_PASSWORD` | secret | The password you set on that `.p12` |

## 1. App Store Connect API key

App Store Connect → Users and Access → Integrations → App Store Connect API →
**+**. Give it **App Manager** access; Developer is not enough to manage
provisioning profiles, which `-allowProvisioningUpdates` needs.

Download `AuthKey_XXXXXXXXXX.p8` — Apple allows this exactly once. Note the Key
ID on the row and the Issuer ID above the table.

```bash
gh variable set APPLE_TEAM_ID --body 'YOURTEAMID' --repo lejacobdev/Fitness
gh secret set ASC_KEY_ID     --body 'YOURKEYID'   --repo lejacobdev/Fitness
gh secret set ASC_ISSUER_ID  --body 'your-issuer-uuid' --repo lejacobdev/Fitness

# From the file, so the key never appears on a command line:
gh secret set ASC_PRIVATE_KEY --repo lejacobdev/Fitness < ~/Downloads/AuthKey_YOURKEYID.p8
```

## 2. Distribution certificate, from Linux

### Generate a key and CSR

```bash
openssl genrsa -out dist.key 2048
openssl req -new -key dist.key -out dist.csr \
  -subj "/emailAddress=you@example.com/CN=Student Athlete Distribution/C=DE"
```

### Have Apple sign it

developer.apple.com → Certificates, Identifiers & Profiles → Certificates → **+**
→ **Apple Distribution** → upload `dist.csr` → download `distribution.cer`.

### Recombine into a `.p12`

```bash
openssl x509 -inform DER -in distribution.cer -out dist.pem
openssl pkcs12 -export \
  -inkey dist.key \
  -in dist.pem \
  -out dist.p12 \
  -name "Apple Distribution" \
  -legacy                      # macOS keychains reject the modern default cipher
```

`-legacy` matters: without it `openssl` 3 uses AES-256-CBC with PBKDF2, and
`security import` on the runner fails with an unhelpful `MAC verification`
error.

### Store it

```bash
base64 -w0 dist.p12 > dist.p12.b64
gh secret set APPLE_DIST_CERT_P12_BASE64 --repo lejacobdev/Fitness < dist.p12.b64
printf '%s' 'the-password-you-chose' | gh secret set APPLE_DIST_CERT_PASSWORD --repo lejacobdev/Fitness

shred -u dist.key dist.p12 dist.p12.b64 dist.pem dist.csr
```

Keep `dist.p12` somewhere safe first if you want to reuse it — §19 is emphatic
that CI must import **one** certificate rather than minting one per run, because
every runner starts with an empty keychain and the account's 15-certificate
ceiling stops builds dead once reached.

## 3. App ID and capabilities — automatable, `tools/asc.mjs` does this

Automatic signing builds the profile from the entitlements file, so a capability
that is missing on the App ID fails the **build**, not the upload. Five are
needed: HealthKit, Sign in with Apple, In-App Purchase, App Groups, Push
Notifications. Unlike app-record creation below, App Store Connect's API
*does* allow creating a bundle ID and enabling capabilities — confirmed by
actually calling it, not assumed:

```bash
ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_PRIVATE_KEY="$(cat AuthKey_*.p8)" \
  node tools/asc.mjs provision com.lejacobdev.studentathlete "Student Athlete"
```

Safe to re-run — both the bundle-id creation and each capability enable are
idempotent (Apple returns the existing resource rather than erroring or
duplicating on a second call). Or drive it through CI instead of locally:

```bash
gh workflow run asc-inspect.yml --repo lejacobdev/Fitness
```

`asc-inspect.yml` is read-only (capability *checking* only); `provision` is
the one that actually creates things, so it is a local/manual `node` call
against the live API, not a workflow — a deliberate choice, since it mutates
the Apple Developer account. Two capabilities have specific traps (§19), both
of which `tools/asc.mjs` already handles:

- **App Groups cannot be fully attached to an App ID by an API key.** Enabling
  the capability flag works over the API (`provision` does this); attaching
  the actual `group.com.lejacobdev.studentathlete` container to the App ID is
  still a manual step — Certificates, Identifiers & Profiles → Identifiers →
  App Groups tab → create the group → back on the App ID's Capabilities →
  App Groups → select it. Skipping it fails the archive with
  `Authentication failed … bearer token` on whichever target needed it.
- **Sign in with Apple is rejected as a bare capability** (409, "select at
  least one configuration") — `provision` sends the required setting
  (`APPLE_ID_AUTH_APP_CONSENT` / `PRIMARY_APP_CONSENT`) automatically.

## 4. The App Store Connect app record — this one is NOT automatable

Confirmed by calling it: `POST /v1/apps` returns `403 "The resource 'apps'
does not allow 'CREATE'"` for every key role. Creating a *new* app has always
required the web UI, full stop — this is the one piece of the whole pipeline
that cannot be scripted.

App Store Connect → My Apps → **+** → New App → iOS → bundle ID
`com.lejacobdev.studentathlete` → pick a unique app name and SKU (the SKU is
internal-only, never shown to users). `xcrun altool --upload-app` fails with
"No suitable application records were found" until this exists.

## 5. First build

```bash
gh workflow run testflight.yml --repo lejacobdev/Fitness
```

`gh workflow run` returns 404 for a minute or two after a workflow file is first
pushed. Retry in a loop rather than concluding it is broken (§19).

The run ends by printing `codesign -d --entitlements :-` for the app and every
nested bundle, plus Apple's `DistributionSummary.plist`. Read them: a build that
silently dropped HealthKit or App Groups uploads exactly as cleanly as a correct
one, and the difference only shows up when a reviewer opens the app.
