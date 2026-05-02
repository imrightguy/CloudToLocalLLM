#!/usr/bin/env node
const { request: httpsRequest } = require('node:https');
const { request: httpRequest } = require('node:http');
const { URL } = require('node:url');

function fetchOnce(url) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const reqImpl = u.protocol === 'http:' ? httpRequest : httpsRequest;
    const req = reqImpl(u, {
      method: 'GET',
      headers: {
        'user-agent': 'paperclip-browser-check/1.0',
        'accept': 'text/html,application/xhtml+xml',
      },
    }, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => {
        const body = Buffer.concat(chunks).toString('utf8');
        resolve({
          status: res.statusCode || 0,
          headers: res.headers,
          body,
        });
      });
    });
    req.on('error', reject);
    req.setTimeout(20000, () => req.destroy(new Error('request timeout')));
    req.end();
  });
}

async function fetchFollow(url, maxRedirects = 5) {
  let current = url;
  const chain = [];
  for (let i = 0; i <= maxRedirects; i++) {
    const res = await fetchOnce(current);
    chain.push({ url: current, status: res.status });
    if ([301, 302, 303, 307, 308].includes(res.status)) {
      const location = res.headers.location;
      if (!location) return { finalUrl: current, chain, ...res };
      current = new URL(location, current).toString();
      continue;
    }
    return { finalUrl: current, chain, ...res };
  }
  throw new Error('too many redirects');
}

function stripHtml(html) {
  return html
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ')
    .replace(/<noscript\b[^>]*>[\s\S]*?<\/noscript>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

function between(str, a, b) {
  const start = str.toLowerCase().indexOf(a.toLowerCase());
  if (start === -1) return null;
  const end = str.toLowerCase().indexOf(b.toLowerCase(), start + a.length);
  if (end === -1) return null;
  return str.slice(start + a.length, end).trim();
}

function classify(text, html, finalUrl) {
  const t = text.toLowerCase();
  const h = html.toLowerCase();
  if (t.includes('ouvrir la démo') || t.includes('chemin de démo recommandé') || t.includes('ouvrir l’application')) {
    return 'public_landing';
  }
  if (t.includes('se connecter') || t.includes('sign in') || t.includes('login')) {
    return 'login_wall';
  }
  if (finalUrl.includes('/dashboard') || t.includes('dashboard') || t.includes('tableau de bord')) {
    return 'app_shell';
  }
  if (h.includes('flutter_service_worker') || h.includes('main.dart.js')) {
    return 'flutter_shell_unknown';
  }
  return 'unknown';
}

async function main() {
  const url = process.argv[2];
  if (!url) {
    console.error('usage: browser-check.js <url>');
    process.exit(2);
  }
  const res = await fetchFollow(url);
  const text = stripHtml(res.body);
  const title = between(res.body, '<title>', '</title>');
  const classification = classify(text, res.body, res.finalUrl);
  const out = {
    inputUrl: url,
    finalUrl: res.finalUrl,
    status: res.status,
    redirects: res.chain,
    title,
    classification,
    bodyPreview: text.slice(0, 500),
    signals: {
      hasMainDartJs: /main\.dart\.js/i.test(res.body),
      hasFlutterServiceWorker: /flutter_service_worker/i.test(res.body),
      hasDemoCTA: /ouvrir la démo/i.test(text),
      hasOpenAppCTA: /ouvrir l’application/i.test(text),
      hasLoginText: /se connecter|sign in|login/i.test(text),
    },
    note: 'Heuristic HTML check from Node. Stronger than plain curl, but not a full JS browser session.',
  };
  console.log(JSON.stringify(out, null, 2));
}

main().catch((err) => {
  console.error(JSON.stringify({ error: String(err.message || err) }, null, 2));
  process.exit(1);
});
