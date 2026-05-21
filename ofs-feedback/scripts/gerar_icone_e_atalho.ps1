# gerar_icone_e_atalho.ps1
# Gera um .ico customizado (escudo azul com "OFS") e cria um atalho
# na Area de Trabalho apontando para iniciar.bat, com o icone gerado.

[CmdletBinding()]
param(
    [string]$ProjectDir = (Split-Path -Parent $PSScriptRoot),
    [string]$ShortcutName = "GESTAO DE OFS"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$assetsDir = Join-Path $ProjectDir "assets"
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir | Out-Null
}
$icoPath = Join-Path $assetsDir "ofs.ico"
$batPath = Join-Path $ProjectDir "iniciar.bat"

if (-not (Test-Path $batPath)) {
    throw "Nao encontrei o iniciar.bat em $batPath"
}

# =====================================================================
# 1. Desenha o icone (256x256) — escudo circular azul com "OFS" branco
# =====================================================================
$size = 256
$bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::Transparent)

# Sombra exterior suave
$shadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 0, 0, 0))
$g.FillEllipse($shadow, 14, 18, 232, 232)

# Fundo: gradiente azul (Security Dynamics)
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(0, 0)),
    (New-Object System.Drawing.Point($size, $size)),
    [System.Drawing.Color]::FromArgb(255, 30, 110, 200),
    [System.Drawing.Color]::FromArgb(255, 8, 38, 90))
$g.FillEllipse($grad, 12, 12, 232, 232)

# Borda branca grossa
$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 8)
$g.DrawEllipse($pen, 16, 16, 224, 224)

# Faixa diagonal verde (estilo "seguro")
$bandColor = [System.Drawing.Color]::FromArgb(220, 34, 197, 94)
$bandBrush = New-Object System.Drawing.SolidBrush($bandColor)
$g.RotateTransform(-20, [System.Drawing.Drawing2D.MatrixOrder]::Prepend)
$g.FillRectangle($bandBrush, -40, 190, 360, 18)
$g.ResetTransform()

# Texto "OFS"
$font = New-Object System.Drawing.Font("Segoe UI", 88, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center
$rect = New-Object System.Drawing.RectangleF(0, -8, $size, $size)
# Sombra do texto
$g.DrawString("OFS", $font, (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 0, 0, 0))), (New-Object System.Drawing.RectangleF(3, -5, $size, $size)), $sf)
# Texto principal
$g.DrawString("OFS", $font, [System.Drawing.Brushes]::White, $rect, $sf)

$g.Dispose()

# =====================================================================
# 2. Salva como .ico (formato PNG-in-ICO, suportado Windows Vista+)
# =====================================================================
$pngStream = New-Object System.IO.MemoryStream
$bmp.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $pngStream.ToArray()
$pngStream.Dispose()
$bmp.Dispose()

$fs = [System.IO.File]::Open($icoPath, [System.IO.FileMode]::Create)
$bw = New-Object System.IO.BinaryWriter($fs)
# ICONDIR
$bw.Write([uint16]0)   # reserved
$bw.Write([uint16]1)   # type = icon
$bw.Write([uint16]1)   # count
# ICONDIRENTRY
$bw.Write([byte]0)     # width  (0 = 256)
$bw.Write([byte]0)     # height (0 = 256)
$bw.Write([byte]0)     # color palette
$bw.Write([byte]0)     # reserved
$bw.Write([uint16]1)   # planes
$bw.Write([uint16]32)  # bits per pixel
$bw.Write([uint32]$pngBytes.Length)  # size
$bw.Write([uint32]22)  # offset (6 + 16)
# PNG payload
$bw.Write($pngBytes)
$bw.Flush()
$bw.Close()
$fs.Close()

Write-Host "Icone gerado: $icoPath"

# =====================================================================
# 3. Cria o atalho na Area de Trabalho
# =====================================================================
$desktop = [Environment]::GetFolderPath("Desktop")
$lnkPath = Join-Path $desktop ($ShortcutName + ".lnk")

$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut($lnkPath)
$lnk.TargetPath = $batPath
$lnk.WorkingDirectory = $ProjectDir
$lnk.IconLocation = "$icoPath,0"
$lnk.Description = "GESTAO DE OFS - Sistema de Feedback Comportamental"
$lnk.WindowStyle = 1
$lnk.Save()

Write-Host "Atalho criado: $lnkPath"
Write-Host ""
Write-Host "Pronto! Da um duplo clique no atalho 'GESTAO DE OFS' na Area de Trabalho."
