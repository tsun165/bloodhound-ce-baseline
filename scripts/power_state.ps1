# Print Windows power mode overlay (effective), AC status and free RAM. ded574b5-... = Best performance.
Add-Type -Namespace W -Name P -MemberDefinition '[DllImport("powrprof.dll")] public static extern uint PowerGetEffectiveOverlayScheme(out Guid g);'
$g=[Guid]::Empty; [W.P]::PowerGetEffectiveOverlayScheme([ref]$g) | Out-Null
"overlay=$g battery_status=$((Get-CimInstance Win32_Battery).BatteryStatus) free_ram_mb=$([int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1024)) cpu_load_pct=$((Get-CimInstance Win32_Processor).LoadPercentage)"
