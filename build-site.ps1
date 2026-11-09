# يبني مجلد site/ القابل للنشر كتطبيق ويب قابل للتثبيت (PWA) من khabeer.html
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$out = Join-Path $root 'site'
New-Item -ItemType Directory -Force $out | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)

# 1) الأيقونات (PNG) — مربع كحلي وحرف «خ»
Add-Type -AssemblyName System.Drawing
function New-Icon([int]$size, [string]$path, [double]$pad) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
  $g.Clear([System.Drawing.Color]::FromArgb(30, 58, 138))
  $font = New-Object System.Drawing.Font('Segoe UI', [float]($size * (0.62 - $pad)), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
  $fmt.FormatFlags = [System.Drawing.StringFormatFlags]::DirectionRightToLeft
  $rect = New-Object System.Drawing.RectangleF 0, ([float]($size * 0.02)), $size, $size
  $g.DrawString([string][char]0x062E, $font, [System.Drawing.Brushes]::White, $rect, $fmt)
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}
New-Icon 192 (Join-Path $out 'icon-192.png') 0
New-Icon 512 (Join-Path $out 'icon-512.png') 0
New-Icon 512 (Join-Path $out 'icon-maskable-512.png') 0.18
New-Icon 180 (Join-Path $out 'apple-touch-icon.png') 0

# 2) الصفحة: نفس ملف النموذج مع هيكل HTML كامل ووسوم التطبيق
$body = [IO.File]::ReadAllText((Join-Path $root 'khabeer.html'), $utf8)
$head = @'
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#1e3a8a">
<meta name="description" content="خبير — المكتب الحقوقي الرقمي: اعرض مشكلتك ونتولى الباقي.">
<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" type="image/png" sizes="192x192" href="icon-192.png">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="خبير">
<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}</style>
</head>
<body>
'@
$tail = @'
<script>
if ('serviceWorker' in navigator) window.addEventListener('load', () => navigator.serviceWorker.register('sw.js').catch(() => {}));
</script>
</body>
</html>
'@
[IO.File]::WriteAllText((Join-Path $out 'index.html'), $head + $body + $tail, $utf8)

# 3) ملف التعريف (Manifest)
$manifest = @'
{
  "name": "خبير — المكتب الحقوقي الرقمي",
  "short_name": "خبير",
  "description": "اعرض مشكلتك الحقوقية كما هي، وفريق خبير يتولى دراستها وتحديد مسارها وحلها.",
  "lang": "ar",
  "dir": "rtl",
  "start_url": "./#client",
  "scope": "./",
  "display": "standalone",
  "orientation": "portrait",
  "background_color": "#f4f6fb",
  "theme_color": "#1e3a8a",
  "categories": ["business", "productivity"],
  "icons": [
    { "src": "icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "icon-512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ],
  "shortcuts": [
    { "name": "طلباتي", "url": "./#client" },
    { "name": "بوابة المحامين", "url": "./#lawyer" },
    { "name": "لوحة الإدارة", "url": "./#admin" }
  ]
}
'@
[IO.File]::WriteAllText((Join-Path $out 'manifest.webmanifest'), $manifest, $utf8)

# 4) عامل الخدمة: يعمل التطبيق دون اتصال بعد أول فتح
$stamp = (Get-Date).ToString('yyyyMMddHHmmss')
$sw = @"
const CACHE = 'khabeer-$stamp';
const SHELL = ['./', 'index.html', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png', 'icon-maskable-512.png', 'apple-touch-icon.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  if (e.request.mode === 'navigate') {
    e.respondWith(fetch(e.request).then(r => { const c = r.clone(); caches.open(CACHE).then(x => x.put('index.html', c)); return r; }).catch(() => caches.match('index.html')));
    return;
  }
  e.respondWith(caches.match(e.request).then(hit => hit || fetch(e.request).then(r => {
    if (r.ok && (url.origin === location.origin || url.hostname.endsWith('gstatic.com') || url.hostname.endsWith('googleapis.com'))) { const c = r.clone(); caches.open(CACHE).then(x => x.put(e.request, c)); }
    return r;
  })));
});
"@
[IO.File]::WriteAllText((Join-Path $out 'sw.js'), $sw, $utf8)

Write-Host "Built: $out"
Get-ChildItem $out | Select-Object Name, Length | Format-Table -AutoSize | Out-String | Write-Host
