Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = fso.BuildPath(baseDir, "EasyAi-DeepSeek.ps1")
ps1 = Replace(ps1, "'", "''")

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command " & Chr(34) & "$p='" & ps1 & "'; $code=[System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($p)); Invoke-Expression $code" & Chr(34)
shell.Run cmd, 0, False
