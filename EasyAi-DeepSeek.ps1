$ErrorActionPreference = "Continue"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$AppName = "EasyAi"
$DeepSeekBaseUrl = "https://api.deepseek.com/anthropic"
$ClaudeInstallUrl = "https://claude.ai/install.ps1"
$DeepSeekApiKeyUrl = "https://platform.deepseek.com/api_keys"
$DefaultModel = "deepseek-v4-pro"
$ConfigDir = Join-Path $env:USERPROFILE ".easyai"
$LogPath = Join-Path $ConfigDir "deepseek-installer.log"
$MissingText = "未安装"
$script:UrgentPopupKeys = @{}

function Mask-Secret {
    param([string]$Value)

    if (-not $Value) {
        return '****'
    }
    if ($Value.Length -le 10) {
        return '****'
    }
    return $Value.Substring(0, 4) + '****' + $Value.Substring($Value.Length - 4)
}

function Ensure-ConfigDir {
    if (-not (Test-Path -LiteralPath $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
}

function Pump-Ui {
    if ($script:Window) {
        $script:Window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Background)
    }
}

function Write-Log {
    param([string]$Message)

    Ensure-ConfigDir
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] $Message"
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8

    if ($script:LogBox) {
        $script:LogBox.AppendText($Message + [Environment]::NewLine)
        $script:LogBox.ScrollToEnd()
        Pump-Ui
    }
}

function Write-LogSection {
    param([string]$Title)
    Write-Log ""
    Write-Log ("========== " + $Title + " ==========")
}

function Set-Status {
    param([string]$Message)

    if ($script:StatusText) {
        $script:StatusText.Text = $Message
        Pump-Ui
    }
}

function Set-Progress {
    param([int]$Value)

    if ($script:ProgressBar) {
        $script:ProgressBar.Value = [Math]::Max(0, [Math]::Min(100, $Value))
        Pump-Ui
    }
}

function Set-Busy {
    param([bool]$Busy)

    foreach ($button in @($script:BtnInstallOnly, $script:BtnFull, $script:BtnConfigOnly, $script:BtnTest, $script:BtnRefresh)) {
        if ($button) {
            $button.IsEnabled = -not $Busy
        }
    }
    Pump-Ui
}

function Show-Info {
    param([string]$Message)
    [System.Windows.MessageBox]::Show($script:Window, $Message, $AppName, "OK", "Information") | Out-Null
}

function Show-Warn {
    param([string]$Message)
    [System.Windows.MessageBox]::Show($script:Window, $Message, $AppName, "OK", "Warning") | Out-Null
}

function Show-Urgent {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Key = ""
    )

    if ($Key) {
        if ($script:UrgentPopupKeys.ContainsKey($Key)) {
            return
        }
        $script:UrgentPopupKeys[$Key] = $true
    }

    [System.Windows.MessageBox]::Show($script:Window, $Message, $Title, "OK", "Warning") | Out-Null
}

function Show-AccountNotice {
    $message = @"
使用前请先了解：

1. Claude Code 是 Anthropic 官方工具，首次启动时可能要求登录或完成官方认证。
2. DeepSeek API Key 只负责模型调用，不是 Claude 账号，也不能绕过 Claude Code 的官方登录或地区限制。
3. 如果当前地区无法下载或使用 Claude Code，本工具只能提示原因，不能替代官方可用性限制。

如果你已经安装好 Claude Code，也可以只用本工具配置 DeepSeek V4 Pro。
"@
    [System.Windows.MessageBox]::Show($script:Window, $message, "使用前须知", "OK", "Information") | Out-Null
}

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Get-ToolVersion {
    param([string]$Command)

    Refresh-ProcessPath
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        return $MissingText
    }

    try {
        $output = & $Command --version 2>&1 | Select-Object -First 1
        if ($LASTEXITCODE -eq 0 -and $output) {
            return [string]$output
        }
        return "已安装，版本检测失败"
    } catch {
        return "已安装，版本检测失败"
    }
}

function Invoke-External {
    param(
        [string]$File,
        [string[]]$Arguments
    )

    Write-Log ("> " + $File + " " + ($Arguments -join " "))
    try {
        $output = & $File @Arguments 2>&1 | Out-String
        if ($output.Trim()) {
            Write-Log $output.Trim()
        }
        if ($null -eq $LASTEXITCODE) {
            return 0
        }
        return [int]$LASTEXITCODE
    } catch {
        Write-Log ("命令执行失败：" + $_.Exception.Message)
        return 1
    }
}

function Set-UserEnv {
    param(
        [string]$Name,
        [string]$Value
    )

    [Environment]::SetEnvironmentVariable($Name, $Value, "User")
    Set-Item -Path ("Env:\" + $Name) -Value $Value

    if ($Name -match "KEY|TOKEN") {
        Write-Log ("已保存 " + $Name + "=****")
    } else {
        Write-Log ("已保存 " + $Name + "=" + $Value)
    }
}

function Test-DeepSeekApiKey {
    param([string]$ApiKey, [string]$Model)

    Write-LogSection "DeepSeek API Key 校验"
    Set-Status "正在校验 DeepSeek API Key..."
    Set-Progress 35
    Write-Log ("Base URL: " + $DeepSeekBaseUrl)
    Write-Log ("验证接口: " + $DeepSeekBaseUrl + "/v1/messages")
    Write-Log ("模型: " + $Model)
    Write-Log ("API Key: " + (Mask-Secret $ApiKey))
    Write-Log "正在发送最小消息请求，用于确认 Key、余额和网络是否可用。"

    $headers = @{
        "x-api-key" = $ApiKey
        "Authorization" = "Bearer $ApiKey"
        "anthropic-version" = "2023-06-01"
        "content-type" = "application/json"
    }
    $body = @{
        model = $Model
        max_tokens = 8
        messages = @(
            @{
                role = "user"
                content = "ping"
            }
        )
    } | ConvertTo-Json -Depth 8

    try {
        $response = Invoke-RestMethod -Method Post -Uri ($DeepSeekBaseUrl + "/v1/messages") -Headers $headers -Body $body -TimeoutSec 30
        if ($response) {
            Write-Log "DeepSeek API Key 校验通过。"
            if ($response.id) {
                Write-Log ("DeepSeek 响应 ID: " + $response.id)
            }
            return $true
        }

        Write-Log "DeepSeek 返回为空，校验失败。"
        return $false
    } catch {
        $status = ""
        $detail = $_.Exception.Message

        if ($_.Exception.Response) {
            try {
                $status = [int]$_.Exception.Response.StatusCode
                $stream = $_.Exception.Response.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $responseText = $reader.ReadToEnd()
                    if ($responseText) {
                        $detail = $responseText
                    }
                }
            } catch {}
        }

        if ($status) {
            Write-Log ("DeepSeek API Key 校验失败，HTTP 状态码：" + $status)
        } else {
            Write-Log "DeepSeek API Key 校验失败。"
        }
        if ($detail) {
            Write-Log ("DeepSeek 返回：" + $detail)
        }
        return $false
    }
}

function Confirm-DeepSeekApiKey {
    param(
        [string]$ApiKey,
        [string]$Model,
        [bool]$ShowSuccessPopup = $true
    )

    Set-Busy $true
    $ok = Test-DeepSeekApiKey $ApiKey $Model
    Set-Busy $false
    if ($ok) {
        if ($ShowSuccessPopup) {
            [System.Windows.MessageBox]::Show(
                $script:Window,
                "DeepSeek API Key 校验通过。`n`n当前 Key 可以访问 DeepSeek Anthropic 接口，模型：" + $Model,
                "API Key 校验成功",
                "OK",
                "Information"
            ) | Out-Null
        }
    } else {
        Show-Warn "DeepSeek API Key 校验失败。`n`n请检查：`n1. API Key 是否复制完整；`n2. DeepSeek 账户是否有余额；`n3. 当前网络是否能访问 api.deepseek.com。"
    }
    return $ok
}

function Test-ClaudeInstallerAccess {
    Write-LogSection "Claude Code 官方下载检测"
    Write-Log ("安装脚本地址: " + $ClaudeInstallUrl)
    Set-Status "正在检查 Claude 官方下载..."
    try {
        $response = Invoke-WebRequest -Uri $ClaudeInstallUrl -UseBasicParsing -TimeoutSec 15
        $content = [string]$response.Content
        if ($content -match "App unavailable in region" -or $content -match "app-unavailable-in-region") {
            return "地区不可用"
        }
        if ($content -match "<html" -and $content -notmatch "powershell|install") {
            return "返回网页，可能被地区或网络限制"
        }
        return "可访问"
    } catch {
        $message = $_.Exception.Message
        if ($message -match "403|Forbidden|unavailable") {
            return "地区不可用或访问被拒绝"
        }
        return "无法确认：" + $message
    }
}

function Show-DownloadAccessPopupIfNeeded {
    param(
        [string]$AccessStatus,
        [bool]$Force = $false
    )

    if ($AccessStatus -match "地区不可用|访问被拒绝") {
        $message = "当前网络或地区无法访问 Claude Code 官方安装服务。`n`n这不是缺少 Python、Node.js 或 Git，而是 Claude Code 官方服务不可用。`n`n你可以在已安装 Claude Code 的电脑上只配置 DeepSeek V4 Pro。"
        if ($Force) {
            [System.Windows.MessageBox]::Show($script:Window, $message, "紧急提示：Claude Code 不可用", "OK", "Warning") | Out-Null
        } else {
            Show-Urgent "紧急提示：Claude Code 不可用" $message "claude-region-unavailable"
        }
        return
    }

    if ($AccessStatus -match "返回网页，可能被地区或网络限制") {
        $message = "Claude Code 官方安装地址返回了异常网页，可能被网络或地区限制。`n`n请不要继续盲目安装 Node.js、Git 或 Python；这些不是根本原因。"
        if ($Force) {
            [System.Windows.MessageBox]::Show($script:Window, $message, "紧急提示：下载异常", "OK", "Warning") | Out-Null
        } else {
            Show-Urgent "紧急提示：下载异常" $message "claude-download-html"
        }
    }
}

function Get-DownloadStatusShort {
    param([string]$AccessStatus)

    if ($AccessStatus -match "可访问") {
        return "可访问"
    }
    if ($AccessStatus -match "地区不可用|访问被拒绝") {
        return "不可用"
    }
    return "异常"
}

function Install-ClaudeCodeNative {
    Write-LogSection "Claude Code 安装"
    Set-Busy $true
    Set-Status "正在安装 Claude Code..."
    Set-Progress 8

    $current = Get-ToolVersion "claude"
    Write-Log ("当前 Claude Code 状态: " + $current)
    if ($current -ne $MissingText) {
        Write-Log ("Claude Code 已安装：" + $current)
        Set-Progress 100
        Set-Busy $false
        return $true
    }

    $access = Test-ClaudeInstallerAccess
    $script:DownloadStatus.Text = $access
    Write-Log ("Claude 官方下载检测：" + $access)
    if ($access -match "地区不可用") {
        Show-DownloadAccessPopupIfNeeded $access $true
        Set-Progress 100
        Set-Busy $false
        return $false
    }

    $ps = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
    if (-not $ps) {
        Show-Warn "未找到 PowerShell，无法运行官方安装器。"
        Set-Busy $false
        return $false
    }

    Write-Log ("PowerShell: " + $ps)
    Write-Log "使用 Claude Code 官方原生安装器。默认不安装 Node.js，也不安装 Git。"
    Set-Progress 28
    $code = Invoke-External $ps @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", "irm https://claude.ai/install.ps1 | iex"
    )

    Set-Progress 70
    Refresh-ProcessPath
    $installed = Get-ToolVersion "claude"
    Write-Log ("官方安装后检测结果: " + $installed)
    if ($installed -ne $MissingText) {
        Write-Log ("Claude Code 安装完成：" + $installed)
        Set-Progress 100
        Set-Busy $false
        return $true
    }

    Write-Log "官方脚本未检测到 claude 命令，尝试 WinGet 备用安装方式。"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $wingetCode = Invoke-External "winget" @(
            "install",
            "--id", "Anthropic.ClaudeCode",
            "-e",
            "--accept-package-agreements",
            "--accept-source-agreements"
        )
        Refresh-ProcessPath
        $installed = Get-ToolVersion "claude"
        Write-Log ("WinGet 安装后检测结果: " + $installed)
        if ($installed -ne $MissingText) {
            Write-Log ("Claude Code 安装完成：" + $installed)
            Set-Progress 100
            Set-Busy $false
            return $true
        }
        Write-Log ("WinGet 退出码：" + $wingetCode)
    } else {
        Write-Log "未检测到 WinGet，跳过备用安装方式。"
    }

    Write-Log ("官方安装器退出码：" + $code)
    Set-Progress 100
    Set-Busy $false
    return $false
}

function Save-DeepSeekConfig {
    param(
        [string]$ApiKey,
        [string]$Model
    )

    Write-LogSection "写入 DeepSeek 配置"
    Set-Busy $true
    Set-Status "正在配置 DeepSeek V4 Pro..."
    Set-Progress 20
    Write-Log ("Base URL: " + $DeepSeekBaseUrl)
    Write-Log ("模型: " + $Model)
    Write-Log ("配置文件目录: " + $ConfigDir)

    Set-UserEnv "ANTHROPIC_BASE_URL" $DeepSeekBaseUrl
    Set-UserEnv "ANTHROPIC_AUTH_TOKEN" $ApiKey
    Set-UserEnv "ANTHROPIC_MODEL" $Model
    Set-UserEnv "ANTHROPIC_DEFAULT_OPUS_MODEL" $Model
    Set-UserEnv "ANTHROPIC_DEFAULT_SONNET_MODEL" $Model
    Set-UserEnv "ANTHROPIC_DEFAULT_HAIKU_MODEL" $Model
    Set-UserEnv "CLAUDE_CODE_SUBAGENT_MODEL" $Model
    Set-UserEnv "CLAUDE_CODE_EFFORT_LEVEL" "think"

    if ($script:CompatCheck.IsChecked) {
        Set-UserEnv "ANTHROPIC_API_KEY" $ApiKey
        Set-UserEnv "DEEPSEEK_API_KEY" $ApiKey
    }

    Ensure-ConfigDir
    $config = [ordered]@{
        base_url = $DeepSeekBaseUrl
        model = $Model
        updated_at = (Get-Date).ToString("s")
    }
    $config | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ConfigDir "deepseek-installer.json") -Encoding UTF8

    Set-Progress 100
    Write-Log "DeepSeek V4 Pro 配置已保存。请新开终端后使用 claude。"
    Set-Busy $false
    return $true
}

function Test-ClaudeCode {
    param(
        [string]$ApiKey,
        [string]$Model,
        [bool]$SkipApiKeyCheck = $false
    )

    Write-LogSection "Claude Code 调用测试"
    Set-Busy $true
    Set-Status "正在测试连接..."
    Set-Progress 20
    Write-Log ("测试模型: " + $Model)

    if (-not $SkipApiKeyCheck -and -not (Test-DeepSeekApiKey $ApiKey $Model)) {
        [System.Windows.MessageBox]::Show(
            $script:Window,
            "DeepSeek API Key 校验失败。`n`n请检查：`n1. API Key 是否复制完整；`n2. DeepSeek 账户是否有余额；`n3. 当前网络是否能访问 api.deepseek.com。",
            "API Key 校验失败",
            "OK",
            "Warning"
        ) | Out-Null
        Set-Progress 100
        Set-Busy $false
        return $false
    }

    if (-not $SkipApiKeyCheck) {
        [System.Windows.MessageBox]::Show(
            $script:Window,
            "DeepSeek API Key 校验通过。`n`n接下来继续测试本机 Claude Code 是否能调用 DeepSeek V4 Pro。",
            "API Key 校验成功",
            "OK",
            "Information"
        ) | Out-Null
    }

    Refresh-ProcessPath
    $claudeVersion = Get-ToolVersion "claude"
    Write-Log ("Claude Code 状态: " + $claudeVersion)
    if ($claudeVersion -eq $MissingText) {
        Write-Log "未检测到 Claude Code，无法测试。"
        Show-Warn "DeepSeek API Key 有效，但当前电脑未检测到 Claude Code。`n`n请先点击“只安装 Claude Code”，或在已安装 Claude Code 的电脑上使用本工具。"
        Set-Progress 100
        Set-Busy $false
        return $false
    }

    $env:ANTHROPIC_BASE_URL = $DeepSeekBaseUrl
    $env:ANTHROPIC_AUTH_TOKEN = $ApiKey
    $env:ANTHROPIC_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
    $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $Model
    $env:CLAUDE_CODE_SUBAGENT_MODEL = $Model
    $env:CLAUDE_CODE_EFFORT_LEVEL = "think"
    Write-Log "已为当前测试进程注入 DeepSeek 环境变量。"

    $code = Invoke-External "claude" @("--print", "请用一句中文回复：EasyAi DeepSeek V4 Pro 已连接。")
    Set-Progress 100

    if ($code -eq 0) {
        Write-Log "连接测试成功。"
        Show-Info "连接测试成功。`n`nDeepSeek API Key 有效，Claude Code 也可以正常调用 DeepSeek V4 Pro。"
        Set-Busy $false
        return $true
    }

    Write-Log ("连接测试失败，退出码：" + $code)
    Show-Warn "DeepSeek API Key 有效，但 Claude Code 测试没有通过。`n`n请优先检查：`n1. Claude Code 是否要求先登录或认证；`n2. 是否刚写入环境变量但还没有新开终端；`n3. 当前网络是否能访问 Claude Code。"
    Set-Busy $false
    return $false
}

function Refresh-EnvironmentView {
    Write-LogSection "安装前检测"
    Set-Busy $true
    Set-Status "正在检测..."
    Set-Progress 15

    $claudeStatus = Get-ToolVersion "claude"
    Write-Log ("Claude Code: " + $claudeStatus)
    $script:ClaudeStatus.Text = if ($claudeStatus -eq $MissingText) { "未安装" } else { "已安装" }
    $script:DeepSeekStatus.Text = if ([Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "User") -eq $DeepSeekBaseUrl) {
        Write-Log "DeepSeek 配置: 已配置"
        "已配置 DeepSeek V4 Pro"
    } else {
        Write-Log "DeepSeek 配置: 未配置"
        "未配置"
    }
    $downloadAccess = Test-ClaudeInstallerAccess
    $script:DownloadStatus.Text = Get-DownloadStatusShort $downloadAccess
    Write-Log ("Claude 官方下载: " + $downloadAccess)
    Show-DownloadAccessPopupIfNeeded $downloadAccess

    Set-Progress 100
    Set-Status "就绪"
    Set-Busy $false
}

function Require-ApiKey {
    $key = $script:ApiKeyBox.Password.Trim()
    if (-not $key) {
        Show-Warn "请先填写 DeepSeek API Key。"
        return $null
    }
    return $key
}

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="EasyAi - DeepSeek V4 Pro"
        Width="1040" Height="760"
        MinWidth="960" MinHeight="700"
        WindowStartupLocation="CenterScreen"
        Background="#F6F8FB"
        FontFamily="Microsoft YaHei UI">
    <Window.Resources>
        <SolidColorBrush x:Key="TextMain" Color="#111827"/>
        <SolidColorBrush x:Key="TextMuted" Color="#64748B"/>
        <SolidColorBrush x:Key="Brand" Color="#2563EB"/>
        <SolidColorBrush x:Key="BrandDark" Color="#1D4ED8"/>
        <Style x:Key="Card" TargetType="Border">
            <Setter Property="Background" Value="White"/>
            <Setter Property="CornerRadius" Value="12"/>
            <Setter Property="Padding" Value="18"/>
            <Setter Property="BorderBrush" Value="#E5E7EB"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Height" Value="42"/>
            <Setter Property="Padding" Value="18,0"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Background" Value="{StaticResource Brand}"/>
            <Setter Property="BorderBrush" Value="{StaticResource Brand}"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="8">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{StaticResource BrandDark}"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.55"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource PrimaryButton}">
            <Setter Property="Foreground" Value="#111827"/>
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#CBD5E1"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#F8FAFC"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Height" Value="34"/>
            <Setter Property="Padding" Value="10,6"/>
            <Setter Property="BorderBrush" Value="#CBD5E1"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="PasswordBox">
            <Setter Property="Height" Value="34"/>
            <Setter Property="Padding" Value="10,6"/>
            <Setter Property="BorderBrush" Value="#CBD5E1"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Height" Value="34"/>
            <Setter Property="Padding" Value="8,4"/>
        </Style>
    </Window.Resources>

    <Grid Margin="22">
        <Grid.RowDefinitions>
            <RowDefinition Height="56"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="36"/>
        </Grid.RowDefinitions>

        <Grid Grid.Row="0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="260"/>
            </Grid.ColumnDefinitions>
            <StackPanel>
                <TextBlock Text="EasyAi DeepSeek V4 Pro" FontSize="24" FontWeight="Bold" Foreground="{StaticResource TextMain}"/>
            </StackPanel>
            <Border Grid.Column="1" Background="#EEF2FF" CornerRadius="18" Padding="14,8" HorizontalAlignment="Right" VerticalAlignment="Top">
                <TextBlock x:Name="StatusText" Text="就绪" Foreground="#1D4ED8" FontWeight="SemiBold"/>
            </Border>
        </Grid>

        <Grid Grid.Row="1">
            <Grid.RowDefinitions>
                <RowDefinition Height="250"/>
                <RowDefinition Height="14"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Grid Grid.Row="0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="360"/>
                    <ColumnDefinition Width="18"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0">
                    <Border Style="{StaticResource Card}">
                        <StackPanel>
                            <TextBlock Text="模块 1｜安装前检测" FontSize="17" FontWeight="Bold" Foreground="{StaticResource TextMain}" Margin="0,0,0,12"/>

                            <Grid Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="116"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Text="Claude Code" Foreground="{StaticResource TextMuted}"/>
                                <TextBlock x:Name="ClaudeStatus" Grid.Column="1" Text="检测中" FontWeight="SemiBold" TextWrapping="Wrap"/>
                            </Grid>
                            <Grid Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="116"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Text="DeepSeek" Foreground="{StaticResource TextMuted}"/>
                                <TextBlock x:Name="DeepSeekStatus" Grid.Column="1" Text="检测中" FontWeight="SemiBold" TextWrapping="Wrap"/>
                            </Grid>
                            <Grid Margin="0,0,0,10">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="116"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <TextBlock Text="官方下载" Foreground="{StaticResource TextMuted}"/>
                                <TextBlock x:Name="DownloadStatus" Grid.Column="1" Text="检测中" FontWeight="SemiBold" TextWrapping="Wrap"/>
                            </Grid>
                        </StackPanel>
                    </Border>

                </StackPanel>

                <StackPanel Grid.Column="2">
                    <Border Style="{StaticResource Card}">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="14"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="12"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="12"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="16"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="120"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <TextBlock Text="模块 2｜DeepSeek 配置" Grid.ColumnSpan="2" FontSize="17" FontWeight="Bold" Foreground="{StaticResource TextMain}"/>

                            <TextBlock Grid.Row="2" Text="Base URL" Foreground="{StaticResource TextMuted}" VerticalAlignment="Center"/>
                            <TextBox Grid.Row="2" Grid.Column="1" Text="https://api.deepseek.com/anthropic" IsReadOnly="True"/>

                            <TextBlock Grid.Row="4" Text="API Key" Foreground="{StaticResource TextMuted}" VerticalAlignment="Center"/>
                            <PasswordBox x:Name="ApiKeyBox" Grid.Row="4" Grid.Column="1"/>

                            <TextBlock Grid.Row="6" Text="模型" Foreground="{StaticResource TextMuted}" VerticalAlignment="Center"/>
                            <ComboBox x:Name="ModelBox" Grid.Row="6" Grid.Column="1" IsEditable="True" Text="deepseek-v4-pro">
                                <ComboBoxItem Content="deepseek-v4-pro"/>
                                <ComboBoxItem Content="deepseek-chat"/>
                                <ComboBoxItem Content="deepseek-reasoner"/>
                            </ComboBox>

                            <StackPanel Grid.Row="8" Grid.Column="1" Orientation="Horizontal">
                                <CheckBox x:Name="CompatCheck" Content="同时写入 ANTHROPIC_API_KEY 和 DEEPSEEK_API_KEY" IsChecked="True" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <Border Style="{StaticResource Card}" Margin="0,14,0,0">
                        <StackPanel>
                            <TextBlock Text="模块 3｜执行操作" FontSize="17" FontWeight="Bold" Foreground="{StaticResource TextMain}" Margin="0,0,0,12"/>
                            <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="12"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="12"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Button x:Name="BtnInstallOnly" Grid.Column="0" Content="安装 Claude Code" Style="{StaticResource SecondaryButton}"/>
                        <Button x:Name="BtnConfigOnly" Grid.Column="2" Content="配置 DeepSeek" Style="{StaticResource SecondaryButton}"/>
                        <Button x:Name="BtnFull" Grid.Column="4" Content="安装并配置" Style="{StaticResource PrimaryButton}"/>
                            </Grid>
                            <Grid Margin="0,12,0,0">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="12"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="12"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Button x:Name="BtnOpenKey" Grid.Column="0" Content="DeepSeek Key" Style="{StaticResource SecondaryButton}"/>
                                <Button x:Name="BtnTest" Grid.Column="2" Content="测试连接" Style="{StaticResource SecondaryButton}"/>
                                <Button x:Name="BtnLogs" Grid.Column="4" Content="日志目录" Style="{StaticResource SecondaryButton}"/>
                            </Grid>
                        </StackPanel>
                    </Border>
                </StackPanel>
            </Grid>

            <Border Grid.Row="2" Style="{StaticResource Card}" Padding="16">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="10"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="模块 4｜运行日志" FontSize="17" FontWeight="Bold" Foreground="{StaticResource TextMain}"/>
                    </Grid>
                    <TextBox x:Name="LogBox" Grid.Row="2" Background="#0F172A" Foreground="#E5E7EB"
                             FontFamily="Consolas" FontSize="12" BorderThickness="0" Padding="12"
                             MinHeight="260"
                             IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap"
                             VerticalScrollBarVisibility="Auto"/>
                </Grid>
            </Border>
        </Grid>

        <Grid Grid.Row="2" Margin="0,14,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition Width="92"/>
            </Grid.ColumnDefinitions>
            <ProgressBar x:Name="ProgressBar" Height="10" VerticalAlignment="Center" Minimum="0" Maximum="100"/>
            <Button x:Name="BtnRefresh" Grid.Column="2" Content="重新检测" Style="{StaticResource SecondaryButton}" Height="32"/>
        </Grid>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$script:Window = [Windows.Markup.XamlReader]::Load($reader)

$script:StatusText = $script:Window.FindName("StatusText")
$script:ClaudeStatus = $script:Window.FindName("ClaudeStatus")
$script:DeepSeekStatus = $script:Window.FindName("DeepSeekStatus")
$script:DownloadStatus = $script:Window.FindName("DownloadStatus")
$script:ApiKeyBox = $script:Window.FindName("ApiKeyBox")
$script:ModelBox = $script:Window.FindName("ModelBox")
$script:CompatCheck = $script:Window.FindName("CompatCheck")
$script:LogBox = $script:Window.FindName("LogBox")
$script:ProgressBar = $script:Window.FindName("ProgressBar")
$script:BtnInstallOnly = $script:Window.FindName("BtnInstallOnly")
$script:BtnFull = $script:Window.FindName("BtnFull")
$script:BtnConfigOnly = $script:Window.FindName("BtnConfigOnly")
$script:BtnOpenKey = $script:Window.FindName("BtnOpenKey")
$script:BtnTest = $script:Window.FindName("BtnTest")
$script:BtnLogs = $script:Window.FindName("BtnLogs")
$script:BtnRefresh = $script:Window.FindName("BtnRefresh")

$script:BtnInstallOnly.Add_Click({
    Set-Progress 0
    if (Install-ClaudeCodeNative) {
        Refresh-EnvironmentView
        Show-Info "Claude Code 已安装。请新打开终端，然后运行：claude"
    } else {
        Show-Warn "Claude Code 安装失败。请查看日志中的原因。"
    }
})

$script:BtnFull.Add_Click({
    $key = Require-ApiKey
    if (-not $key) { return }
    Set-Progress 0
    if (-not (Confirm-DeepSeekApiKey $key $script:ModelBox.Text $true)) {
        return
    }
    if (-not (Install-ClaudeCodeNative)) {
        Show-Warn "Claude Code 安装失败。请查看日志中的原因。"
        return
    }
    Save-DeepSeekConfig $key $script:ModelBox.Text | Out-Null
    Test-ClaudeCode $key $script:ModelBox.Text $true | Out-Null
    Refresh-EnvironmentView
})

$script:BtnConfigOnly.Add_Click({
    $key = Require-ApiKey
    if (-not $key) { return }
    Set-Progress 0
    if (-not (Confirm-DeepSeekApiKey $key $script:ModelBox.Text $true)) {
        return
    }
    Save-DeepSeekConfig $key $script:ModelBox.Text | Out-Null
    Refresh-EnvironmentView
    Show-Info "DeepSeek API Key 校验通过，DeepSeek V4 Pro 已配置。`n`n请新打开终端后使用 claude。"
})

$script:BtnOpenKey.Add_Click({
    Start-Process $DeepSeekApiKeyUrl
})

$script:BtnTest.Add_Click({
    $key = Require-ApiKey
    if (-not $key) { return }
    Set-Progress 0
    Test-ClaudeCode $key $script:ModelBox.Text | Out-Null
})

$script:BtnLogs.Add_Click({
    Ensure-ConfigDir
    Start-Process explorer.exe $ConfigDir
})

$script:BtnRefresh.Add_Click({
    Refresh-EnvironmentView
})

$script:Window.Add_Loaded({
    Write-Log "EasyAi 启动。"
    Show-AccountNotice
    Refresh-EnvironmentView
})

if ($env:EASYAI_XAML_CHECK -eq "1") {
    Write-Output "WPF UI load check passed."
    exit 0
}

[void]$script:Window.ShowDialog()
