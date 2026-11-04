# Widget: % hạn mức token đã dùng, nằm mờ trên thanh tiêu đề cửa sổ Claude. Chuột phải để đóng.
# Chỉ chạy một bản: bản mở sau sẽ tự thoát.
$mutex = New-Object System.Threading.Mutex($false, 'Local\ClaudeTokenMeterWidget')
try { if (-not $mutex.WaitOne(0)) { exit } } catch [System.Threading.AbandonedMutexException] { }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class TokenWin {
  [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Ri, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int ht, uint flags);
  [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] public static extern IntPtr SetOwner(IntPtr h, int index, IntPtr owner);
}
'@

$dataFile = Join-Path $env:USERPROFILE '.claude\token-meter.json'
$names = @{ five_hour = '5h'; seven_day = 'Tuần'; seven_day_fable = 'Fable'; spend_limit = 'Chi tiêu' }
$idleOpacity = 0.55
# Khoảng cách từ mép phải cửa sổ Claude tới mép phải widget, và chiều cao thanh tiêu đề (đơn vị 96 DPI).
$rightGap = 360
$titleHeight = 36

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Token" SizeToContent="WidthAndHeight" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ShowInTaskbar="False" ResizeMode="NoResize" ShowActivated="False">
  <Border VerticalAlignment="Center" HorizontalAlignment="Center" CornerRadius="5" Background="#B31F1F1E" Padding="7,2">
    <TextBlock Name="Line" Foreground="White" FontSize="11"/>
  </Border>
</Window>
'@
$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$line = $win.FindName('Line')
$win.Opacity = $idleOpacity
$script:me = [IntPtr]::Zero
$script:claude = [IntPtr]::Zero

function Brush($hex) { [Windows.Media.BrushConverter]::new().ConvertFromString($hex) }

function Find-Claude {
  if ($script:claude -ne [IntPtr]::Zero -and [TokenWin]::IsWindow($script:claude)) { return }
  $p = Get-Process -Name claude -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  $script:claude = if ($p) { $p.MainWindowHandle } else { [IntPtr]::Zero }
  if ($script:me -eq [IntPtr]::Zero) { return }
  # Thuộc về cửa sổ Claude: nằm ngay trên nó, thu nhỏ theo nó, không đè lên app khác.
  [void][TokenWin]::SetOwner($script:me, -8, $script:claude)
  $win.Topmost = ($script:claude -eq [IntPtr]::Zero)
}

function Move-ToTitle {
  if ($script:me -eq [IntPtr]::Zero) { return }
  if ($script:claude -eq [IntPtr]::Zero) {
    $area = [Windows.SystemParameters]::WorkArea
    $win.Left = $area.Right - $win.ActualWidth - 16
    $win.Top = $area.Top + 16
    return
  }
  $r = New-Object TokenWin+R
  $o = New-Object TokenWin+R
  if (-not [TokenWin]::GetWindowRect($script:claude, [ref]$r)) { return }
  [void][TokenWin]::GetWindowRect($script:me, [ref]$o)
  $scale = [TokenWin]::GetDpiForWindow($script:claude) / 96
  $w = $o.Ri - $o.L
  $h = $o.B - $o.T
  $x = [int]($r.Ri - $rightGap * $scale - $w)
  $y = [int]([Math]::Max($r.T, 0) + ($titleHeight * $scale - $h) / 2)
  if ($x -ne $o.L -or $y -ne $o.T) {
    # SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
    [void][TokenWin]::SetWindowPos($script:me, [IntPtr]::Zero, $x, $y, 0, 0, 0x15)
  }
}

function Update-View {
  try {
    $d = Get-Content -Raw -Encoding UTF8 $dataFile | ConvertFrom-Json
  } catch {
    $line.Text = 'Chưa có số'; return
  }
  $line.Inlines.Clear()
  $now = Get-Date
  $tips = @()
  $first = $true
  foreach ($l in $d.limits) {
    $name = if ($names.ContainsKey($l.kind)) { $names[$l.kind] } else { $l.kind }
    $pct = $l.percentUsed
    if ($l.resetsAt) {
      $at = ([datetime]$l.resetsAt).ToLocalTime()
      if ($at -lt $now) { $pct = $null; $tips += "${name}: đã qua giờ đặt lại, chờ số mới" }
      else { $tips += "${name}: đặt lại " + $at.ToString('HH:mm dd/MM') }
    }
    if (-not $first) { $line.Inlines.Add((New-Object Windows.Documents.Run ' · ')) }
    $first = $false
    $line.Inlines.Add((New-Object Windows.Documents.Run "$name "))
    $value = New-Object Windows.Documents.Run $(if ($null -eq $pct) { '—' } else { "$pct%" })
    if ($pct -ge 95) { $value.Foreground = Brush '#FFFF6B6B' } elseif ($pct -ge 80) { $value.Foreground = Brush '#FFF5A524' }
    $line.Inlines.Add($value)
  }
  $tips += 'Cập nhật ' + ([datetime]$d.updatedAt).ToLocalTime().ToString('HH:mm:ss')
  $win.ToolTip = $tips -join "`n"
}

$win.Add_MouseEnter({ $win.Opacity = 1 })
$win.Add_MouseLeave({ $win.Opacity = $idleOpacity })
$menu = New-Object Windows.Controls.ContextMenu
$quit = New-Object Windows.Controls.MenuItem
$quit.Header = 'Đóng'
$quit.Add_Click({ $win.Close() })
[void]$menu.Items.Add($quit)
$win.ContextMenu = $menu

$win.Add_Loaded({
  $script:me = (New-Object Windows.Interop.WindowInteropHelper $win).Handle
  $script:claude = [IntPtr]::Zero
  Find-Claude
  Move-ToTitle
})

Update-View
$slow = New-Object Windows.Threading.DispatcherTimer
$slow.Interval = [TimeSpan]::FromSeconds(5)
$slow.Add_Tick({ Update-View; Find-Claude })
$slow.Start()
$fast = New-Object Windows.Threading.DispatcherTimer
$fast.Interval = [TimeSpan]::FromMilliseconds(100)
$fast.Add_Tick({ Move-ToTitle })
$fast.Start()
[void]$win.ShowDialog()
