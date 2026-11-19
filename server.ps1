# May chu nho chay bai hoc tai http://localhost:8765
# - Phat video YouTube ngay trong bai
# - Luu cau hinh vao data\config.json, luu anh/video tai len vao images\custom, images\icons, videos
$port = 8765
$root = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') + '\'
$mime = @{ '.html'='text/html; charset=utf-8'; '.js'='application/javascript; charset=utf-8'; '.css'='text/css; charset=utf-8';
  '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.png'='image/png'; '.webp'='image/webp'; '.gif'='image/gif'; '.svg'='image/svg+xml';
  '.mp3'='audio/mpeg'; '.ogg'='audio/ogg'; '.wav'='audio/wav'; '.mp4'='video/mp4'; '.webm'='video/webm'; '.mov'='video/quicktime'; '.m4v'='video/mp4';
  '.json'='application/json; charset=utf-8'; '.txt'='text/plain; charset=utf-8' }
$allowDirs = @('images/custom', 'images/icons', 'videos')
$utf8 = New-Object System.Text.UTF8Encoding $false

function Send-Text($res, $code, $text, $type) {
  $b = $utf8.GetBytes($text); $res.StatusCode = $code; $res.ContentType = $type
  $res.ContentLength64 = $b.Length; $res.OutputStream.Write($b, 0, $b.Length)
}
function Safe-Name($n) {
  $n = [IO.Path]::GetFileName($n)
  $n = [Text.RegularExpressions.Regex]::Replace($n.Normalize([Text.NormalizationForm]::FormD), '\p{Mn}', '')
  $n = $n -replace '[^A-Za-z0-9._-]', '_'
  if ($n.Length -gt 80) { $n = $n.Substring($n.Length - 80) }
  if ($n -eq '' -or $n -match '^\.') { $n = 'file' + $n }
  return $n
}

$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$port/")
try { $l.Start() } catch { Write-Host "Cong $port dang duoc dung (co the bai hoc dang chay roi). Mo trinh duyet..."; Start-Process "http://localhost:$port/index.html"; Start-Sleep 3; exit }
Start-Process "http://localhost:$port/index.html"
Write-Host ""
Write-Host "  CHUYEN TAU XUYEN VIET dang chay tai: http://localhost:$port"
Write-Host "  Moi thay doi duoc luu vao thu muc: $root"
Write-Host "  Giu cua so nay mo trong luc day. Dong cua so de tat."
Write-Host ""

while ($l.IsListening) {
  $c = $l.GetContext(); $req = $c.Request; $res = $c.Response
  try {
    $path = [Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/'))

    if ($req.HttpMethod -eq 'POST' -and $path -eq 'api/config') {
      $sr = New-Object IO.StreamReader($req.InputStream, $utf8); $txt = $sr.ReadToEnd(); $sr.Close()
      $dir = Join-Path $root 'data'; if (-not (Test-Path $dir)) { [void](New-Item -ItemType Directory -Path $dir) }
      $cfg = Join-Path $dir 'config.json'
      if (Test-Path $cfg) { Copy-Item $cfg (Join-Path $dir 'config.backup.json') -Force }
      [IO.File]::WriteAllText($cfg, $txt, $utf8)
      Write-Host ("  [" + (Get-Date -Format HH:mm:ss) + "] Da luu cau hinh")
      Send-Text $res 200 '{"ok":true}' 'application/json'
    }
    elseif ($req.HttpMethod -eq 'POST' -and $path -eq 'api/upload') {
      $d = $req.QueryString['dir']; if ($allowDirs -notcontains $d) { $d = 'images/custom' }
      $name = Safe-Name $req.QueryString['name']
      $dir = Join-Path $root ($d -replace '/', '\'); if (-not (Test-Path $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
      $target = Join-Path $dir $name
      if (Test-Path $target) { $target = Join-Path $dir ([IO.Path]::GetFileNameWithoutExtension($name) + '_' + (Get-Date -Format yyyyMMddHHmmss) + [IO.Path]::GetExtension($name)) }
      $fs = [IO.File]::Create($target); $req.InputStream.CopyTo($fs); $fs.Close()
      $rel = $d + '/' + [IO.Path]::GetFileName($target)
      Write-Host ("  [" + (Get-Date -Format HH:mm:ss) + "] Da luu file: " + $rel)
      Send-Text $res 200 ('{"path":"' + $rel + '"}') 'application/json'
    }
    else {
      if ($path -eq '') { $path = 'index.html' }
      $full = [IO.Path]::GetFullPath((Join-Path $root $path))
      if (-not $full.StartsWith($root) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
        Send-Text $res 404 'Not found' 'text/plain'
      } else {
        $ext = [IO.Path]::GetExtension($full).ToLower()
        $res.ContentType = $(if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' })
        $res.AddHeader('Accept-Ranges', 'bytes'); $res.AddHeader('Cache-Control', 'no-cache')
        $fs = [IO.File]::OpenRead($full); $len = $fs.Length; $start = 0; $end = $len - 1
        $rg = $req.Headers['Range']
        if ($rg -and $rg -match 'bytes=(\d*)-(\d*)') {
          if ($matches[1]) { $start = [int64]$matches[1] }
          if ($matches[2]) { $end = [Math]::Min([int64]$matches[2], $len - 1) }
          $res.StatusCode = 206; $res.AddHeader('Content-Range', "bytes $start-$end/$len")
        }
        $res.ContentLength64 = $end - $start + 1
        [void]$fs.Seek($start, 'Begin')
        $buf = New-Object byte[] 262144; $left = $end - $start + 1
        while ($left -gt 0) { $n = $fs.Read($buf, 0, [int][Math]::Min($buf.Length, $left)); if ($n -le 0) { break }; $res.OutputStream.Write($buf, 0, $n); $left -= $n }
        $fs.Close()
      }
    }
  } catch { Write-Host ("  Loi: " + $_.Exception.Message) } finally { try { $res.Close() } catch { } }
}
