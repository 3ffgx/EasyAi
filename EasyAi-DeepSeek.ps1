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
$ClaudeConfigDir = Join-Path $env:USERPROFILE ".claude"
$ClaudeSettingsPath = Join-Path $ClaudeConfigDir "settings.json"
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

function Ensure-ClaudeConfigDir {
    if (-not (Test-Path -LiteralPath $ClaudeConfigDir)) {
        New-Item -ItemType Directory -Path $ClaudeConfigDir -Force | Out-Null
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
        $brush = "#E5E7EB"
        if ($Message -match "^[=]{20,}|^\[阶段\]") {
            $brush = "#F8FAFC"
        } elseif ($Message -match "^---- ") {
            $brush = "#60A5FA"
        } elseif ($Message -match "^> ") {
            $brush = "#FBBF24"
        } elseif ($Message -match "校验通过|安装完成|连接测试成功|配置已保存|已更新|已备份|可访问") {
            $brush = "#34D399"
        } elseif ($Message -match "失败|不可用|异常|取消|退出码: [1-9]") {
            $brush = "#F87171"
        } elseif ($Message -match "命令输出|测试模型|Base URL|模型:|配置文件|备份文件|下一步|Claude Code:|DeepSeek 配置:|Claude 官方下载:") {
            $brush = "#C084FC"
        }

        $paragraph = New-Object System.Windows.Documents.Paragraph
        $paragraph.Margin = [System.Windows.Thickness]::new(0)
        $run = New-Object System.Windows.Documents.Run($Message)
        $run.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($brush)
        $paragraph.Inlines.Add($run) | Out-Null
        $script:LogBox.Document.Blocks.Add($paragraph)
        $script:LogBox.ScrollToEnd()
        Pump-Ui
    }
}

function Write-LogSection {
    param([string]$Title)
    Write-Log ""
    Write-Log "============================================================"
    Write-Log ("[阶段] " + $Title)
    Write-Log "============================================================"
}

function Write-LogStep {
    param([string]$Title)
    Write-Log ("---- " + $Title + " ----")
}

function Set-ResultSummary {
    param(
        [string]$Stage = $null,
        [string]$Result = $null,
        [string]$SettingsPath = $null,
        [string]$BackupPath = $null,
        [string]$NextAction = $null
    )

    if ($null -ne $Stage -and $script:SummaryStageValue) {
        $script:SummaryStageValue.Text = $Stage
    }
    if ($null -ne $Result -and $script:SummaryResultValue) {
        $script:SummaryResultValue.Text = $Result
    }
    if ($null -ne $SettingsPath -and $script:SummaryPathValue) {
        $script:SummaryPathValue.Text = $SettingsPath
    }
    if ($null -ne $BackupPath -and $script:SummaryBackupValue) {
        $script:SummaryBackupValue.Text = $BackupPath
    }
    if ($null -ne $NextAction -and $script:SummaryNextValue) {
        $script:SummaryNextValue.Text = $NextAction
    }
    Pump-Ui
}

function Set-Status {
    param([string]$Message)

    if ($script:StatusText) {
        $script:StatusText.Text = $Message
        Pump-Ui
    }
    Set-ResultSummary -Stage $Message
    if ($script:ProgressStatusText) {
        $script:ProgressStatusText.Text = $Message
        Pump-Ui
    }
}

function Set-Progress {
    param([int]$Value)

    $progressValue = [Math]::Max(0, [Math]::Min(100, $Value))
    if ($script:ProgressBar) {
        $script:ProgressBar.Value = $progressValue
        Pump-Ui
    }
    if ($script:ProgressPopupBar) {
        $script:ProgressPopupBar.Value = $progressValue
        Pump-Ui
    }
}

function Show-ProgressPopup {
    if (-not $script:ProgressWindow) {
        return
    }
    if (-not $script:ProgressWindow.IsVisible) {
        $script:ProgressWindow.Owner = $script:Window
        $script:ProgressWindow.WindowStartupLocation = "CenterOwner"
        $script:ProgressWindow.Show()
    }
    Pump-Ui
}

function Hide-ProgressPopup {
    if ($script:ProgressWindow -and $script:ProgressWindow.IsVisible) {
        $script:ProgressWindow.Hide()
    }
}

function Set-Busy {
    param([bool]$Busy)

    foreach ($button in @($script:BtnInstallOnly, $script:BtnFull, $script:BtnConfigOnly, $script:BtnTest, $script:BtnRefresh, $script:BtnSaveKey, $script:BtnOpenKey, $script:BtnLogs)) {
        if ($button) {
            $button.IsEnabled = -not $Busy
        }
    }
    if ($Busy) {
        Show-ProgressPopup
    } else {
        Hide-ProgressPopup
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

    Write-LogStep ("执行命令: " + $File)
    Write-Log ("> " + $File + " " + ($Arguments -join " "))
    try {
        $output = & $File @Arguments 2>&1 | Out-String
        if ($output.Trim()) {
            Write-LogStep "命令输出"
            Write-Log $output.Trim()
        }
        if ($null -eq $LASTEXITCODE) {
            Write-Log ("命令退出码: 0")
            return 0
        }
        Write-Log ("命令退出码: " + [int]$LASTEXITCODE)
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

function Get-ObjectPropertyValue {
    param(
        $Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    if ($Object -is [System.Collections.IDictionary]) {
        return $Object[$Name]
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }

    return $null
}

function Set-ObjectPropertyValue {
    param(
        $Object,
        [string]$Name,
        $Value
    )

    if ($Object -is [System.Collections.IDictionary]) {
        $Object[$Name] = $Value
        return
    }

    if ($Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function New-ClaudeSettingsBackupPath {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    return (Join-Path $ClaudeConfigDir ("settings.backup-{0}.json" -f $stamp))
}

function Get-ClaudeEnvMap {
    param(
        [string]$ApiKey,
        [string]$Model
    )

    $envMap = [ordered]@{
        ANTHROPIC_BASE_URL = $DeepSeekBaseUrl
        ANTHROPIC_AUTH_TOKEN = $ApiKey
        ANTHROPIC_MODEL = $Model
        ANTHROPIC_DEFAULT_OPUS_MODEL = $Model
        ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
        ANTHROPIC_DEFAULT_HAIKU_MODEL = $Model
        CLAUDE_CODE_SUBAGENT_MODEL = $Model
        CLAUDE_CODE_EFFORT_LEVEL = "think"
    }

    if ($script:CompatCheck.IsChecked) {
        $envMap["ANTHROPIC_API_KEY"] = $ApiKey
        $envMap["DEEPSEEK_API_KEY"] = $ApiKey
    }

    return $envMap
}

function Read-ClaudeSettings {
    if (-not (Test-Path -LiteralPath $ClaudeSettingsPath)) {
        return [pscustomobject]@{}
    }

    $raw = Get-Content -LiteralPath $ClaudeSettingsPath -Raw -Encoding UTF8
    if (-not $raw.Trim()) {
        return [pscustomobject]@{}
    }

    try {
        return ($raw | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        throw ("Claude 设置文件不是有效 JSON：{0}" -f $_.Exception.Message)
    }
}

function Save-ClaudeSettings {
    param(
        [string]$ApiKey,
        [string]$Model
    )

    Ensure-ClaudeConfigDir
    $settings = Read-ClaudeSettings
    $envSettings = Get-ObjectPropertyValue $settings "env"
    if ($null -eq $envSettings -or $envSettings -is [string] -or $envSettings -is [ValueType]) {
        $envSettings = [pscustomobject]@{}
        Set-ObjectPropertyValue $settings "env" $envSettings
    }

    Write-LogStep "合并 settings.json"
    foreach ($entry in (Get-ClaudeEnvMap $ApiKey $Model).GetEnumerator()) {
        Set-ObjectPropertyValue $envSettings $entry.Key $entry.Value
        if ($entry.Key -match "KEY|TOKEN") {
            Write-Log ("settings.json env 已写入 " + $entry.Key + "=****")
        } else {
            Write-Log ("settings.json env 已写入 " + $entry.Key + "=" + $entry.Value)
        }
    }

    $backupPath = $null
    if (Test-Path -LiteralPath $ClaudeSettingsPath) {
        Write-LogStep "备份现有 settings.json"
        $backupPath = New-ClaudeSettingsBackupPath
        Copy-Item -LiteralPath $ClaudeSettingsPath -Destination $backupPath -Force
        Write-Log ("已备份现有 Claude 设置: " + $backupPath)
    }

    Write-LogStep "写入新的 settings.json"
    $json = $settings | ConvertTo-Json -Depth 20
    Set-Content -LiteralPath $ClaudeSettingsPath -Value $json -Encoding UTF8
    Write-Log ("Claude 设置已更新: " + $ClaudeSettingsPath)

    return $backupPath
}

function Confirm-ClaudeSettingsOverwrite {
    if (-not (Test-Path -LiteralPath $ClaudeSettingsPath)) {
        return $true
    }

    $message = @"
检测到本机已经存在 Claude 配置文件：

$ClaudeSettingsPath

继续写入会：
1. 保留原文件备份；
2. 合并 EasyAi 需要的模型配置；
3. 覆盖同名字段。

是否继续？
"@

    $result = [System.Windows.MessageBox]::Show(
        $script:Window,
        $message,
        "重要确认：发现现有 Claude 配置",
        "YesNo",
        "Warning"
    )

    return ($result -eq [System.Windows.MessageBoxResult]::Yes)
}

function Show-ConfigSavedResult {
    param(
        [string]$SettingsPath,
        [string]$BackupPath
    )

    $message = "Claude / DeepSeek 配置写入完成。`n`n配置文件位置：`n$SettingsPath"
    if ($BackupPath) {
        $message += "`n`n原文件备份：`n$BackupPath"
    }
    $message += "`n`n请新打开终端后使用 claude。"

    Set-ResultSummary -Result "配置已写入" -SettingsPath $SettingsPath -BackupPath ($(if ($BackupPath) { $BackupPath } else { "未生成备份" })) -NextAction "新开终端后运行 claude。"
    Show-Info $message
}

function Get-DeepSeekConfigState {
    try {
        $settings = Read-ClaudeSettings
        $envSettings = Get-ObjectPropertyValue $settings "env"
        $settingsBaseUrl = [string](Get-ObjectPropertyValue $envSettings "ANTHROPIC_BASE_URL")
        $settingsToken = [string](Get-ObjectPropertyValue $envSettings "ANTHROPIC_AUTH_TOKEN")
        if ($settingsBaseUrl -eq $DeepSeekBaseUrl -and $settingsToken) {
            return [pscustomobject]@{
                IsConfigured = $true
                StatusText = "已配置（settings.json）"
            }
        }
    } catch {
        Write-Log $_.Exception.Message
        return [pscustomobject]@{
            IsConfigured = $false
            StatusText = "配置文件异常"
        }
    }

    $legacyBaseUrl = [Environment]::GetEnvironmentVariable("ANTHROPIC_BASE_URL", "User")
    $legacyToken = [Environment]::GetEnvironmentVariable("ANTHROPIC_AUTH_TOKEN", "User")
    if ($legacyBaseUrl -eq $DeepSeekBaseUrl -and $legacyToken) {
        return [pscustomobject]@{
            IsConfigured = $true
            StatusText = "已配置（旧环境变量）"
        }
    }

    return [pscustomobject]@{
        IsConfigured = $false
        StatusText = "未配置"
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
    Write-LogStep "发送最小请求"
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
        Set-ResultSummary -Result "API Key 校验通过" -NextAction "可以继续安装、配置或测试 Claude。"
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
        Set-ResultSummary -Result "API Key 校验失败" -NextAction "检查 Key、余额和网络后重试。"
        Show-Warn "DeepSeek API Key 校验失败。`n`n请检查：`n1. API Key 是否复制完整；`n2. DeepSeek 账户是否有余额；`n3. 当前网络是否能访问 api.deepseek.com。"
    }
    return $ok
}

function Test-ClaudeInstallerAccess {
    Write-LogSection "Claude Code 官方下载检测"
    Write-Log ("安装脚本地址: " + $ClaudeInstallUrl)
    Write-LogStep "检查官方下载地址"
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
    Write-LogStep "检查本机安装状态"
    Write-Log ("当前 Claude Code 状态: " + $current)
    if ($current -ne $MissingText) {
        Write-Log ("Claude Code 已安装：" + $current)
        Set-ResultSummary -Result "Claude Code 已安装" -NextAction "可以直接配置模型或测试连接。"
        Set-Progress 100
        Set-Busy $false
        return $true
    }

    $access = Test-ClaudeInstallerAccess
    Write-LogStep "确认官方下载可用性"
    $script:DownloadStatus.Text = $access
    Write-Log ("Claude 官方下载检测：" + $access)
    if ($access -match "地区不可用") {
        Set-ResultSummary -Result "官方下载不可用" -NextAction "可在已安装 Claude Code 的电脑上只配置模型。"
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
    Write-LogStep "运行官方安装器"
    $code = Invoke-External $ps @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", "irm https://claude.ai/install.ps1 | iex"
    )

    Set-Progress 70
    Refresh-ProcessPath
    Write-LogStep "安装后复检"
    $installed = Get-ToolVersion "claude"
    Write-Log ("官方安装后检测结果: " + $installed)
    if ($installed -ne $MissingText) {
        Write-Log ("Claude Code 安装完成：" + $installed)
        Set-ResultSummary -Result "Claude Code 安装完成" -NextAction "下一步可继续写入模型配置。"
        Set-Progress 100
        Set-Busy $false
        return $true
    }

    Write-Log "官方脚本未检测到 claude 命令，尝试 WinGet 备用安装方式。"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-LogStep "尝试 WinGet 备用安装"
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
            Set-ResultSummary -Result "Claude Code 安装完成" -NextAction "下一步可继续写入模型配置。"
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
    Write-LogStep "准备写入模型配置"
    Write-Log ("Base URL: " + $DeepSeekBaseUrl)
    Write-Log ("模型: " + $Model)
    Write-Log ("Claude 设置文件: " + $ClaudeSettingsPath)

    if (-not (Confirm-ClaudeSettingsOverwrite)) {
        Write-Log "用户取消写入：检测到现有 Claude 配置文件。"
        Set-ResultSummary -Result "已取消写入" -NextAction "如需覆盖现有配置，请重新执行并确认。"
        Set-Status "已取消写入"
        Set-Progress 100
        Set-Busy $false
        return $false
    }

    try {
        Write-LogStep "写入 Claude 配置文件"
        $backupPath = Save-ClaudeSettings $ApiKey $Model
    } catch {
        Write-Log ("写入 Claude 设置失败：" + $_.Exception.Message)
        Show-Warn "Claude 设置写入失败。`n`n请检查 ~/.claude/settings.json 是否被占用，或者里面是不是无效 JSON。"
        Set-Progress 100
        Set-Busy $false
        return $false
    }

    Ensure-ConfigDir
    Write-LogStep "写入 EasyAi 本地记录"
    $config = [ordered]@{
        base_url = $DeepSeekBaseUrl
        model = $Model
        claude_settings_path = $ClaudeSettingsPath
        claude_settings_backup = $backupPath
        updated_at = (Get-Date).ToString("s")
    }
    $config | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ConfigDir "deepseek-installer.json") -Encoding UTF8

    Set-Progress 100
    if ($backupPath) {
        Write-Log ("DeepSeek V4 Pro 配置已保存，原 Claude 设置已备份到: " + $backupPath)
    } else {
        Write-Log "DeepSeek V4 Pro 配置已保存。"
    }
    Show-ConfigSavedResult $ClaudeSettingsPath $backupPath
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
    Write-LogStep "准备测试 Claude 调用"
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
    Write-LogStep "检查 claude 命令"
    $claudeVersion = Get-ToolVersion "claude"
    Write-Log ("Claude Code 状态: " + $claudeVersion)
    if ($claudeVersion -eq $MissingText) {
        Write-Log "未检测到 Claude Code，无法测试。"
        Show-Warn "DeepSeek API Key 有效，但当前电脑未检测到 Claude Code。`n`n请先点击“只安装 Claude Code”，或在已安装 Claude Code 的电脑上使用本工具。"
        Set-Progress 100
        Set-Busy $false
        return $false
    }

    foreach ($entry in (Get-ClaudeEnvMap $ApiKey $Model).GetEnumerator()) {
        Set-Item -Path ("Env:\" + $entry.Key) -Value $entry.Value
    }
    Write-LogStep "注入当前测试进程配置"
    Write-Log "已为当前测试进程注入 Claude/DeepSeek 配置。"

    Write-LogStep "调用 claude --print"
    $code = Invoke-External "claude" @("--print", "Reply in one short English sentence: EasyAi DeepSeek V4 Pro is connected.")
    Set-Progress 100

    if ($code -eq 0) {
        Write-Log "连接测试成功。"
        Set-ResultSummary -Result "连接测试成功" -NextAction "可以直接开始使用 claude。"
        Show-Info "连接测试成功。`n`nDeepSeek API Key 有效，Claude Code 也可以正常调用 DeepSeek V4 Pro。"
        Set-Busy $false
        return $true
    }

    Write-Log ("连接测试失败，退出码：" + $code)
    Set-ResultSummary -Result "连接测试失败" -NextAction "优先检查 Claude 登录、网络和本地终端。"
    Show-Warn "DeepSeek API Key 有效，但 Claude Code 测试没有通过。`n`n请优先检查：`n1. Claude Code 是否要求先登录或认证；`n2. 是否刚写入环境变量但还没有新开终端；`n3. 当前网络是否能访问 Claude Code。"
    Set-Busy $false
    return $false
}

function Refresh-EnvironmentView {
    Write-LogSection "安装前检测"
    Set-Busy $true
    Set-Status "正在检测..."
    Set-Progress 15

    Write-LogStep "检测 Claude Code"
    $claudeStatus = Get-ToolVersion "claude"
    Write-Log ("Claude Code: " + $claudeStatus)
    $script:ClaudeStatus.Text = if ($claudeStatus -eq $MissingText) { "未安装" } else { "已安装" }
    Write-LogStep "检测模型配置"
    $deepSeekState = Get-DeepSeekConfigState
    Write-Log ("DeepSeek 配置: " + $deepSeekState.StatusText)
    $script:DeepSeekStatus.Text = $deepSeekState.StatusText
    Write-LogStep "检测官方下载"
    $downloadAccess = Test-ClaudeInstallerAccess
    $script:DownloadStatus.Text = Get-DownloadStatusShort $downloadAccess
    Write-Log ("Claude 官方下载: " + $downloadAccess)
    Set-ResultSummary -Result ("检测完成：" + $downloadAccess) -NextAction "填写 Key 后可继续安装或配置。"
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
        Title="EasyAi"
        Width="1180" Height="860"
        MinWidth="1080" MinHeight="780"
        WindowStartupLocation="CenterScreen"
        Background="#F6F8FB"
        FontFamily="Microsoft YaHei UI">
    <Window.Resources>
        <SolidColorBrush x:Key="TextMain" Color="#111827"/>
        <SolidColorBrush x:Key="TextMuted" Color="#64748B"/>
        <SolidColorBrush x:Key="Brand" Color="#2563EB"/>
        <SolidColorBrush x:Key="BrandDark" Color="#1D4ED8"/>
        <SolidColorBrush x:Key="PanelTint" Color="#EFF6FF"/>
        <Style x:Key="Card" TargetType="Border">
            <Setter Property="Background" Value="White"/>
            <Setter Property="CornerRadius" Value="16"/>
            <Setter Property="Padding" Value="22"/>
            <Setter Property="BorderBrush" Value="#E2E8F0"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Height" Value="44"/>
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
        <Style x:Key="SuccessButton" TargetType="Button" BasedOn="{StaticResource PrimaryButton}">
            <Setter Property="Background" Value="#16A34A"/>
            <Setter Property="BorderBrush" Value="#16A34A"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#15803D"/>
                    <Setter Property="BorderBrush" Value="#15803D"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Height" Value="40"/>
            <Setter Property="Padding" Value="12,7"/>
            <Setter Property="BorderBrush" Value="#CBD5E1"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="PasswordBox">
            <Setter Property="Height" Value="40"/>
            <Setter Property="Padding" Value="12,7"/>
            <Setter Property="BorderBrush" Value="#CBD5E1"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Height" Value="40"/>
            <Setter Property="Padding" Value="10,5"/>
        </Style>
    </Window.Resources>

    <Grid Margin="22">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="18"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Grid Grid.Row="0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="12"/>
                <ColumnDefinition Width="130"/>
            </Grid.ColumnDefinitions>
            <StackPanel>
                <TextBlock Text="EasyAi" FontSize="34" FontWeight="Bold" Foreground="{StaticResource TextMain}"/>
                <StackPanel Orientation="Horizontal" Margin="0,6,0,0">
                    <TextBlock Text="作者 3ffgx  |  QQ 1405936435" Foreground="{StaticResource TextMuted}" VerticalAlignment="Center"/>
                    <Button x:Name="BtnRepoHeader" Content="GitHub 仓库" Style="{StaticResource SecondaryButton}" Height="30" Padding="10,0" Margin="12,0,0,0"/>
                </StackPanel>
            </StackPanel>
            <Border Grid.Column="1" Background="#EEF2FF" CornerRadius="20" Padding="18,10" HorizontalAlignment="Right" VerticalAlignment="Center">
                <TextBlock x:Name="StatusText" Text="就绪" Foreground="#1D4ED8" FontWeight="SemiBold"/>
            </Border>
            <Button x:Name="BtnRefresh" Grid.Column="3" Content="重新检测" Style="{StaticResource SuccessButton}" Height="40"/>
        </Grid>

        <Grid Grid.Row="2">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="18"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Border Grid.Row="0" Style="{StaticResource Card}">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="16"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="18"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="124"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Grid Grid.Row="0" Grid.ColumnSpan="2">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="16"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="16"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0">
                            <TextBlock Text="国产模型配置" FontSize="18" FontWeight="Bold" Foreground="{StaticResource TextMain}"/>
                        </StackPanel>

                        <Border Grid.Column="1" Background="{StaticResource PanelTint}" CornerRadius="999" Padding="14,8">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="Claude Code " Foreground="{StaticResource TextMuted}"/>
                                <TextBlock x:Name="ClaudeStatus" Text="检测中" FontWeight="SemiBold"/>
                            </StackPanel>
                        </Border>

                        <Border Grid.Column="3" Background="{StaticResource PanelTint}" CornerRadius="999" Padding="14,8">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="模型配置 " Foreground="{StaticResource TextMuted}"/>
                                <TextBlock x:Name="DeepSeekStatus" Text="检测中" FontWeight="SemiBold"/>
                            </StackPanel>
                        </Border>

                        <Border Grid.Column="5" Background="{StaticResource PanelTint}" CornerRadius="999" Padding="14,8">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="官方下载 " Foreground="{StaticResource TextMuted}"/>
                                <TextBlock x:Name="DownloadStatus" Text="检测中" FontWeight="SemiBold"/>
                            </StackPanel>
                        </Border>
                    </Grid>

                    <TextBlock Grid.Row="2" Text="Base URL" Foreground="{StaticResource TextMuted}" VerticalAlignment="Center"/>
                    <TextBox Grid.Row="2" Grid.Column="1" Text="https://api.deepseek.com/anthropic" IsReadOnly="True"/>

                    <Grid Grid.Row="4" Grid.ColumnSpan="2">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="124"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="14"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="14"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="18"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="14"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <TextBlock Grid.Row="0" Text="API Key" Foreground="{StaticResource TextMuted}" VerticalAlignment="Center"/>
                        <PasswordBox x:Name="ApiKeyBox" Grid.Row="0" Grid.Column="1"/>

                        <TextBlock Grid.Row="2" Text="模型" Foreground="{StaticResource TextMuted}" VerticalAlignment="Center"/>
                        <ComboBox x:Name="ModelBox" Grid.Row="2" Grid.Column="1" IsEditable="True" Text="deepseek-v4-pro">
                            <ComboBoxItem Content="deepseek-v4-pro"/>
                            <ComboBoxItem Content="deepseek-chat"/>
                            <ComboBoxItem Content="deepseek-reasoner"/>
                        </ComboBox>

                        <TextBlock Grid.Row="4" Text="兼容模式" Foreground="{StaticResource TextMuted}" VerticalAlignment="Center"/>
                        <CheckBox x:Name="CompatCheck" Grid.Row="4" Grid.Column="1" Content="同时写入 ANTHROPIC_API_KEY 和 DEEPSEEK_API_KEY" IsChecked="True" VerticalAlignment="Center"/>

                        <Grid Grid.Row="6" Grid.ColumnSpan="2">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Button x:Name="BtnInstallOnly" Grid.Column="0" Content="只安装 Claude Code" Style="{StaticResource SecondaryButton}"/>
                            <Button x:Name="BtnConfigOnly" Grid.Column="2" Content="只配置模型" Style="{StaticResource SecondaryButton}"/>
                            <Button x:Name="BtnFull" Grid.Column="4" Content="一键安装并配置" Style="{StaticResource PrimaryButton}"/>
                        </Grid>

                        <Grid Grid.Row="8" Grid.ColumnSpan="2">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Button x:Name="BtnSaveKey" Grid.Column="0" Content="仅保存配置" Style="{StaticResource SecondaryButton}"/>
                            <Button x:Name="BtnTest" Grid.Column="2" Content="测试连接" Style="{StaticResource SecondaryButton}"/>
                            <Button x:Name="BtnOpenKey" Grid.Column="4" Content="打开 Key 页面" Style="{StaticResource SecondaryButton}"/>
                            <Button x:Name="BtnLogs" Grid.Column="6" Content="打开日志目录" Style="{StaticResource SecondaryButton}"/>
                        </Grid>
                    </Grid>
                </Grid>
            </Border>

            <Border Grid.Row="2" Style="{StaticResource Card}" Padding="18">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="3*"/>
                        <ColumnDefinition Width="16"/>
                        <ColumnDefinition Width="2*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Column="0" Background="#000000" CornerRadius="10" Padding="16">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="12"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <TextBlock Text="运行日志" FontSize="18" FontWeight="Bold" Foreground="White"/>
                            <RichTextBox x:Name="LogBox" Grid.Row="2" Background="#000000" Foreground="#E5E7EB"
                                         FontFamily="Consolas" FontSize="12" BorderThickness="0" Padding="0"
                                         IsReadOnly="True" IsDocumentEnabled="False"
                                         VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
                                <FlowDocument PagePadding="0" TextAlignment="Left"/>
                            </RichTextBox>
                        </Grid>
                    </Border>

                    <Border Grid.Column="2" Background="#F8FAFC" BorderBrush="#E2E8F0" BorderThickness="1" CornerRadius="10" Padding="16">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="14"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="12"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="12"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="12"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="12"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="12"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <TextBlock Text="结果面板" FontSize="18" FontWeight="Bold" Foreground="{StaticResource TextMain}"/>

                            <Border Grid.Row="2" Background="White" CornerRadius="8" Padding="12" BorderBrush="#E2E8F0" BorderThickness="1">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="78"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="当前阶段" Foreground="{StaticResource TextMuted}"/>
                                    <TextBlock x:Name="SummaryStageValue" Grid.Column="1" Text="就绪" FontWeight="SemiBold" TextWrapping="Wrap"/>
                                </Grid>
                            </Border>

                            <Border Grid.Row="4" Background="White" CornerRadius="8" Padding="12" BorderBrush="#E2E8F0" BorderThickness="1">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="78"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="最近结果" Foreground="{StaticResource TextMuted}"/>
                                    <TextBlock x:Name="SummaryResultValue" Grid.Column="1" Text="等待操作" FontWeight="SemiBold" TextWrapping="Wrap"/>
                                </Grid>
                            </Border>

                            <Border Grid.Row="6" Background="White" CornerRadius="8" Padding="12" BorderBrush="#E2E8F0" BorderThickness="1">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="78"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="配置文件" Foreground="{StaticResource TextMuted}"/>
                                    <TextBlock x:Name="SummaryPathValue" Grid.Column="1" Text="~/.claude/settings.json" FontWeight="SemiBold" TextWrapping="Wrap"/>
                                </Grid>
                            </Border>

                            <Border Grid.Row="8" Background="White" CornerRadius="8" Padding="12" BorderBrush="#E2E8F0" BorderThickness="1">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="78"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="备份文件" Foreground="{StaticResource TextMuted}"/>
                                    <TextBlock x:Name="SummaryBackupValue" Grid.Column="1" Text="尚未生成" FontWeight="SemiBold" TextWrapping="Wrap"/>
                                </Grid>
                            </Border>

                            <Border Grid.Row="10" Background="#EEF2FF" CornerRadius="8" Padding="12">
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="78"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Text="下一步" Foreground="{StaticResource TextMuted}"/>
                                    <TextBlock x:Name="SummaryNextValue" Grid.Column="1" Text="填写 Key 后开始操作。" FontWeight="SemiBold" TextWrapping="Wrap"/>
                                </Grid>
                            </Border>

                            <Border Grid.Row="12" Background="White" CornerRadius="8" Padding="12" BorderBrush="#E2E8F0" BorderThickness="1">
                                <Grid>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="8"/>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="8"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    <TextBlock Text="作者：3ffgx" Foreground="{StaticResource TextMain}" FontWeight="SemiBold"/>
                                    <StackPanel Grid.Row="2">
                                        <TextBlock Text="仓库：" Foreground="{StaticResource TextMuted}"/>
                                        <Button x:Name="BtnRepo" Content="3ffgx/EasyAi.git" Style="{StaticResource SecondaryButton}" Height="34" Margin="0,6,0,0"/>
                                    </StackPanel>
                                    <TextBlock Grid.Row="4" Text="问题反馈 QQ：1405936435" Foreground="{StaticResource TextMuted}" TextWrapping="Wrap"/>
                                </Grid>
                            </Border>
                        </Grid>
                    </Border>
                </Grid>
            </Border>
        </Grid>
    </Grid>
</Window>
"@

$progressXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="EasyAi"
        Width="420" Height="150"
        ResizeMode="NoResize"
        WindowStyle="ToolWindow"
        ShowInTaskbar="False"
        Background="White"
        FontFamily="Microsoft YaHei UI">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="14"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock x:Name="ProgressStatusText" Text="正在处理..." FontSize="16" FontWeight="SemiBold" Foreground="#111827"/>
        <ProgressBar x:Name="ProgressPopupBar" Grid.Row="2" Height="14" Minimum="0" Maximum="100"/>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$script:Window = [Windows.Markup.XamlReader]::Load($reader)
$progressReader = New-Object System.Xml.XmlNodeReader ([xml]$progressXaml)
$script:ProgressWindow = [Windows.Markup.XamlReader]::Load($progressReader)

$script:StatusText = $script:Window.FindName("StatusText")
$script:ClaudeStatus = $script:Window.FindName("ClaudeStatus")
$script:DeepSeekStatus = $script:Window.FindName("DeepSeekStatus")
$script:DownloadStatus = $script:Window.FindName("DownloadStatus")
$script:ApiKeyBox = $script:Window.FindName("ApiKeyBox")
$script:ModelBox = $script:Window.FindName("ModelBox")
$script:CompatCheck = $script:Window.FindName("CompatCheck")
$script:LogBox = $script:Window.FindName("LogBox")
$script:SummaryStageValue = $script:Window.FindName("SummaryStageValue")
$script:SummaryResultValue = $script:Window.FindName("SummaryResultValue")
$script:SummaryPathValue = $script:Window.FindName("SummaryPathValue")
$script:SummaryBackupValue = $script:Window.FindName("SummaryBackupValue")
$script:SummaryNextValue = $script:Window.FindName("SummaryNextValue")
$script:BtnInstallOnly = $script:Window.FindName("BtnInstallOnly")
$script:BtnFull = $script:Window.FindName("BtnFull")
$script:BtnConfigOnly = $script:Window.FindName("BtnConfigOnly")
$script:BtnOpenKey = $script:Window.FindName("BtnOpenKey")
$script:BtnTest = $script:Window.FindName("BtnTest")
$script:BtnLogs = $script:Window.FindName("BtnLogs")
$script:BtnRefresh = $script:Window.FindName("BtnRefresh")
$script:BtnSaveKey = $script:Window.FindName("BtnSaveKey")
$script:BtnRepo = $script:Window.FindName("BtnRepo")
$script:BtnRepoHeader = $script:Window.FindName("BtnRepoHeader")
$script:ProgressStatusText = $script:ProgressWindow.FindName("ProgressStatusText")
$script:ProgressPopupBar = $script:ProgressWindow.FindName("ProgressPopupBar")

$script:BtnInstallOnly.Add_Click({
    Write-LogSection "用户操作：只安装 Claude Code"
    Set-Progress 0
    if (Install-ClaudeCodeNative) {
        Refresh-EnvironmentView
        Show-Info "Claude Code 已安装。请新打开终端，然后运行：claude"
    } else {
        Show-Warn "Claude Code 安装失败。请查看日志中的原因。"
    }
})

$script:BtnFull.Add_Click({
    Write-LogSection "用户操作：一键安装并配置"
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
    Write-LogSection "用户操作：只配置模型"
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

$script:BtnSaveKey.Add_Click({
    Write-LogSection "用户操作：仅保存配置"
    $key = Require-ApiKey
    if (-not $key) { return }
    Set-Progress 0
    if (-not (Confirm-DeepSeekApiKey $key $script:ModelBox.Text $true)) {
        return
    }
    Save-DeepSeekConfig $key $script:ModelBox.Text | Out-Null
    Refresh-EnvironmentView
    Show-Info "API Key 已保存，DeepSeek V4 Pro 已配置。`n`n请新打开终端后使用 claude。"
})

$script:BtnOpenKey.Add_Click({
    Start-Process $DeepSeekApiKeyUrl
})

$script:BtnRepo.Add_Click({
    Start-Process "https://github.com/3ffgx/EasyAi.git"
})

$script:BtnRepoHeader.Add_Click({
    Start-Process "https://github.com/3ffgx/EasyAi.git"
})

$script:BtnTest.Add_Click({
    Write-LogSection "用户操作：测试连接"
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
    Write-LogSection "用户操作：重新检测"
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
