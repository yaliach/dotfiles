---
name: security-headers
description: >
  Next.js security headers configuration for production-ready applications.
  Use when configuring Next.js projects or adding new routes that need special
  security considerations. Covers Content Security Policy (CSP), HSTS, X-Frame-Options,
  and other critical security headers. Ensures protection against XSS, clickjacking,
  MIME sniffing, and other web vulnerabilities.
---

This skill covers the complete security headers configuration used in this project.
These headers provide defense-in-depth protection against common web vulnerabilities
and are essential for production deployments.

Cross-reference the `better-auth-integration` skill when modifying CSP for auth-related
features, and the `api-routes-js` skill for API-specific security considerations.

## Security Headers Overview

Security headers are HTTP response headers that instruct the browser on how to
handle content securely. They provide critical protections against:

- **XSS attacks** - Cross-Site Scripting
- **Clickjacking** - Embedding site in iframe
- **MIME sniffing** - Browser guessing content type
- **Man-in-the-middle attacks** - Downgrade to HTTP
- **Information leakage** - Referrer information
- **Unnecessary feature access** - Camera, microphone, etc.

## Next.js Configuration (next.config.ts)

```typescript
// next.config.ts
import type { NextConfig } from "next"

const nextConfig: NextConfig = {
  async headers() {
    return [
      {
        // Apply headers to all routes
        source: '/(.*)',
        headers: [
          // Prevent MIME type sniffing
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          
          // Control referrer information
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
          
          // Prevent clickjacking
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          
          // Force HTTPS (HTTP Strict Transport Security)
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=31536000; includeSubDomains',
          },
          
          // Content Security Policy
          {
            key: 'Content-Security-Policy',
            value: [
              "default-src 'self'",
              "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
              "style-src 'self' 'unsafe-inline'",
              "img-src 'self' data: https:",
              "font-src 'self' data:",
              "connect-src 'self'",
              "frame-ancestors 'none'",
              "base-uri 'self'",
              "form-action 'self'",
            ].join('; '),
          },
          
          // XSS Protection (legacy, kept for older browsers)
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block',
          },
          
          // Control browser features
          {
            key: 'Permissions-Policy',
            value: [
              'camera=()',
              'microphone=()',
              'geolocation=()',
              'interest-cohort=()',
            ].join(', '),
          },
        ],
      },
    ]
  },
}

export default nextConfig
```

## Header Explanations

### X-Content-Type-Options: nosniff

**Purpose:** Prevents browsers from MIME-sniffing (guessing content type).

**Protection:** Prevents XSS attacks where attacker uploads malicious content
with incorrect MIME type, hoping browser will execute it.

```typescript
{
  key: 'X-Content-Type-Options',
  value: 'nosniff',
}
```

**Example attack prevented:**
- User uploads "image.jpg" that's actually JavaScript
- Without header: Browser might execute it as JS
- With header: Browser respects Content-Type and refuses to execute

### Referrer-Policy: strict-origin-when-cross-origin

**Purpose:** Controls how much referrer information is sent with requests.

**Options:**
- `no-referrer` - Never send referrer (most private, may break analytics)
- `strict-origin-when-cross-origin` - Send full URL for same-origin, only origin for cross-origin (recommended)
- `same-origin` - Send referrer only for same-origin requests
- `origin` - Send only the origin, never full URL

```typescript
{
  key: 'Referrer-Policy',
  value: 'strict-origin-when-cross-origin',
}
```

**What it means:**
- Same-origin request: `https://yoursite.com/page` → Full URL sent as referrer
- Cross-origin request: `https://yoursite.com/page` → Only `https://yoursite.com` sent
- HTTPS → HTTP: No referrer sent (downgrade protection)

### X-Frame-Options: DENY

**Purpose:** Prevents clickjacking by disallowing page embedding in iframes.

**Options:**
- `DENY` - Never allow framing (most secure)
- `SAMEORIGIN` - Allow framing only by same origin
- `ALLOW-FROM uri` - Allow specific origin (deprecated, use CSP instead)

```typescript
{
  key: 'X-Frame-Options',
  value: 'DENY',
}
```

**Attack prevented:**
```html
<!-- Attacker site -->
<iframe src="https://yoursite.com/admin/delete-user">
  <!-- Overlay transparent button to trick user into clicking -->
</iframe>
```

**When to use SAMEORIGIN:**
If you need to embed your own pages in iframes (e.g., embedded widgets):

```typescript
{
  key: 'X-Frame-Options',
  value: 'SAMEORIGIN',
}
```

### Strict-Transport-Security (HSTS)

**Purpose:** Forces browser to use HTTPS for all future requests.

**Format:** `max-age=<seconds>; includeSubDomains; preload`

```typescript
{
  key: 'Strict-Transport-Security',
  value: 'max-age=31536000; includeSubDomains',
}
```

**Parameters:**
- `max-age=31536000` - Remember for 1 year (31536000 seconds)
- `includeSubDomains` - Apply to all subdomains
- `preload` - (Optional) Submit to HSTS preload list (Chrome, Firefox, etc.)

**Protection:**
- First visit: User types `http://yoursite.com`
- Server redirects to `https://yoursite.com` with HSTS header
- Future visits: Browser automatically uses HTTPS (no HTTP request ever made)
- Prevents SSL stripping attacks

**For preload list:**
```typescript
value: 'max-age=31536000; includeSubDomains; preload',
```
Then submit at https://hstspreload.org/

### Content-Security-Policy (CSP)

**Purpose:** Controls which resources browser is allowed to load.

**Most important header for XSS prevention.**

```typescript
{
  key: 'Content-Security-Policy',
  value: [
    "default-src 'self'",                    // Default: only same origin
    "script-src 'self' 'unsafe-inline' 'unsafe-eval'",  // Scripts
    "style-src 'self' 'unsafe-inline'",      // Stylesheets
    "img-src 'self' data: https:",           // Images
    "font-src 'self' data:",                 // Fonts
    "connect-src 'self'",                    // AJAX, WebSocket, fetch
    "frame-ancestors 'none'",                // Framing (replaces X-Frame-Options)
    "base-uri 'self'",                       // <base> tag
    "form-action 'self'",                    // Form submission
  ].join('; '),
}
```

#### CSP Directives Explained

**default-src 'self'**
- Default policy for all resource types
- `'self'` = Same origin only
- Other directives override this for specific types

**script-src 'self' 'unsafe-inline' 'unsafe-eval'**
- `'self'` - Load scripts from same origin
- `'unsafe-inline'` - Allow inline `<script>` tags and event handlers (needed for Next.js)
- `'unsafe-eval'` - Allow `eval()` and `new Function()` (needed for Next.js dev)

**Important:** In production, try to remove `'unsafe-inline'` and `'unsafe-eval'` by using nonces:

```typescript
// More secure (requires nonce generation)
"script-src 'self' 'nonce-{random-nonce}'",
```

**style-src 'self' 'unsafe-inline'**
- Allow stylesheets from same origin
- `'unsafe-inline'` - Allow inline `<style>` tags and `style` attributes (needed for Tailwind)

**img-src 'self' data: https:**
- `'self'` - Same origin images
- `data:` - Data URLs (e.g., `data:image/png;base64,...`)
- `https:` - Any HTTPS image (useful for CDNs, user avatars, etc.)

**To restrict to specific domains:**
```typescript
"img-src 'self' data: https://cdn.example.com https://images.example.com",
```

**font-src 'self' data:**
- Allow fonts from same origin and data URLs
- Add Google Fonts if needed: `font-src 'self' data: https://fonts.gstatic.com`

**connect-src 'self'**
- Controls AJAX, fetch, WebSocket, EventSource
- `'self'` - Only same origin API calls

**To allow external APIs:**
```typescript
"connect-src 'self' https://api.example.com",
```

**frame-ancestors 'none'**
- Modern replacement for X-Frame-Options
- `'none'` = DENY (never allow framing)
- `'self'` = SAMEORIGIN (allow same-origin framing)

**base-uri 'self'**
- Restricts URLs that can be used in `<base>` tag
- Prevents attacker from injecting `<base href="https://attacker.com">`

**form-action 'self'**
- Restricts where forms can submit to
- Prevents form hijacking

#### Common CSP Modifications

**Allow Google Fonts:**
```typescript
"style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
"font-src 'self' data: https://fonts.gstatic.com",
```

**Allow Google Analytics:**
```typescript
"script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.google-analytics.com",
"connect-src 'self' https://www.google-analytics.com",
"img-src 'self' data: https: https://www.google-analytics.com",
```

**Allow external images (e.g., user avatars from CDN):**
```typescript
"img-src 'self' data: https: https://cdn.yourservice.com",
```

**Allow WebSocket connections:**
```typescript
"connect-src 'self' wss://yoursite.com",
```

### X-XSS-Protection: 1; mode=block

**Purpose:** Legacy XSS filter for older browsers.

**Modern browsers:** Use CSP instead (better protection).

```typescript
{
  key: 'X-XSS-Protection',
  value: '1; mode=block',
}
```

**Options:**
- `0` - Disable XSS filter
- `1` - Enable XSS filter (sanitize page)
- `1; mode=block` - Enable and block page entirely if XSS detected (safer)

**Note:** Some modern browsers (Chrome 78+) have removed this feature entirely,
relying on CSP. Keep for compatibility with older browsers.

### Permissions-Policy

**Purpose:** Control which browser features and APIs can be used.

**Formerly:** Feature-Policy (renamed to Permissions-Policy).

```typescript
{
  key: 'Permissions-Policy',
  value: [
    'camera=()',              // No site can use camera
    'microphone=()',          // No site can use microphone
    'geolocation=()',         // No site can use geolocation
    'interest-cohort=()',     // Opt out of FLoC (Google's tracking)
  ].join(', '),
}
```

**Format:** `feature=(allowed-origins)`

**Examples:**
```typescript
// Disable all features
'camera=()'

// Allow same origin
'camera=(self)'

// Allow specific origins
'camera=(self "https://trusted.com")'

// Allow all origins (not recommended)
'camera=*'
```

**Common features to control:**
- `camera` - Camera access
- `microphone` - Microphone access
- `geolocation` - Location access
- `payment` - Payment Request API
- `usb` - WebUSB API
- `accelerometer` - Accelerometer sensor
- `gyroscope` - Gyroscope sensor
- `interest-cohort` - FLoC (Google's tracking, opt-out recommended)

**If you need camera/mic (e.g., video chat app):**
```typescript
value: [
  'camera=(self)',
  'microphone=(self)',
  'geolocation=()',
  'interest-cohort=()',
].join(', '),
```

## Testing Security Headers

### Browser DevTools

1. Open DevTools (F12)
2. Go to Network tab
3. Reload page
4. Click on document request (usually first one)
5. Go to "Headers" section
6. Check "Response Headers"

**What to verify:**
- [ ] X-Content-Type-Options: nosniff
- [ ] X-Frame-Options: DENY
- [ ] Strict-Transport-Security present (if HTTPS)
- [ ] Content-Security-Policy present
- [ ] Referrer-Policy present
- [ ] Permissions-Policy present

### Online Tools

**securityheaders.com:**
```
https://securityheaders.com/?q=https://yoursite.com
```
- Grades your headers (A+ is perfect)
- Shows missing headers
- Provides recommendations

**Mozilla Observatory:**
```
https://observatory.mozilla.org/
```
- Comprehensive security scan
- Checks headers, TLS, cookies, etc.
- Provides detailed report

### Command Line (curl)

```bash
curl -I https://yoursite.com

# Or specifically check for security headers
curl -I https://yoursite.com | grep -E "(X-Frame-Options|Content-Security-Policy|Strict-Transport-Security)"
```

## CSP Violation Reporting

Enable CSP reporting to catch violations:

```typescript
{
  key: 'Content-Security-Policy',
  value: [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
    // ... other directives
    "report-uri https://yoursite.com/api/csp-report",  // Where to send reports
  ].join('; '),
}
```

### CSP Report Endpoint

```typescript
// app/api/csp-report/route.ts
export async function POST(req: Request) {
  try {
    const report = await req.json()
    
    // Log violation
    logger.warn({ report }, 'CSP violation detected')
    
    // Optionally send to monitoring service (Sentry, etc.)
    
    return new Response('', { status: 204 })
  } catch (err) {
    return new Response('', { status: 400 })
  }
}
```

### Report-Only Mode

Test CSP without breaking your site:

```typescript
{
  key: 'Content-Security-Policy-Report-Only',  // Note: Report-Only
  value: "default-src 'self'; report-uri https://yoursite.com/api/csp-report",
}
```

- Violations are reported but not enforced
- Use to test new CSP policies before deploying

## Route-Specific Headers

Apply different headers to specific routes:

```typescript
// next.config.ts
async headers() {
  return [
    {
      // Strict CSP for API routes
      source: '/api/:path*',
      headers: [
        {
          key: 'Content-Security-Policy',
          value: "default-src 'none'",  // Very strict
        },
      ],
    },
    {
      // More permissive for public pages
      source: '/(.*)',
      headers: [
        // ... standard headers
      ],
    },
  ]
}
```

## HTTPS Considerations

### Development vs. Production

**Development (localhost):**
- HSTS not needed (localhost is exempt)
- CSP may need `'unsafe-inline'` and `'unsafe-eval'` for hot reload

**Production:**
- HSTS required
- Stricter CSP if possible (use nonces instead of `'unsafe-inline'`)
- Ensure HTTPS is properly configured

### Redirecting HTTP to HTTPS

Next.js doesn't handle this - use your hosting provider:

**Vercel:** Automatic HTTPS redirect

**Custom server (nginx):**
```nginx
server {
    listen 80;
    server_name yoursite.com;
    return 301 https://$server_name$request_uri;
}
```

**Next.js middleware (not recommended for production):**
```typescript
// middleware.ts
export function middleware(request: NextRequest) {
  if (request.nextUrl.protocol === 'http:') {
    const url = request.nextUrl.clone()
    url.protocol = 'https:'
    return NextResponse.redirect(url)
  }
}
```

## Common Issues

### CSP Breaking Inline Styles

**Problem:** Tailwind uses inline styles, CSP blocks them.

**Solution:** Keep `'unsafe-inline'` in `style-src`, or use nonces:

```typescript
// With nonces (advanced)
"style-src 'self' 'nonce-{random-nonce}'",
```

### CSP Breaking Next.js Hot Reload

**Problem:** Next.js dev server uses `eval()` for hot reload.

**Solution:** Allow `'unsafe-eval'` in development:

```typescript
const isDev = process.env.NODE_ENV === 'development'

"script-src 'self' 'unsafe-inline' " + (isDev ? "'unsafe-eval'" : ""),
```

### X-Frame-Options Preventing Embeds

**Problem:** Need to embed your page in iframe (e.g., for docs, widgets).

**Solution:** Change to `SAMEORIGIN` or remove for specific routes:

```typescript
{
  source: '/embed/:path*',
  headers: [
    { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
  ],
}
```

### HSTS Breaking Local Development

**Problem:** HSTS forces HTTPS, but local dev uses HTTP.

**Solution:** Don't set HSTS in development, or clear HSTS cache:

Chrome: `chrome://net-internals/#hsts` → Delete domain

## Security Checklist

Before deploying to production:

- [ ] All security headers configured in next.config.ts
- [ ] CSP tested and not breaking functionality
- [ ] HSTS enabled (if using HTTPS)
- [ ] X-Frame-Options set to DENY or SAMEORIGIN
- [ ] Permissions-Policy restricts unnecessary features
- [ ] Headers tested with securityheaders.com (aim for A or A+)
- [ ] CSP violations monitored (if using report-uri)
- [ ] HTTPS properly configured (if hosting supports it)
- [ ] No sensitive data in client-side JavaScript
- [ ] Environment variables not exposed to client

## Related Skills

- **better-auth-integration** - Auth endpoints may need CSP exceptions
- **api-routes-js** - API routes can have stricter CSP
- **logging-js** - Log CSP violations for monitoring
