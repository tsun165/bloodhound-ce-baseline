#!/usr/bin/env bash
# Snapshot the environment into logs/env/<before|after>/ (redacted).
# Usage: scripts/capture_env.sh <before|after> [host|neo4j|all]
#   host  : hardware.txt docker.txt images.txt compose.resolved.yml
#   neo4j : neo4j.txt (stack must be up)
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
phase=$1; part=${2:-all}
D=logs/env/$phase; mkdir -p "$D"
set -a; . ./.env; set +a
export REDACT_HOST=$(hostname) REDACT_USER=${USERNAME:-${USER:-}} REDACT_EMAIL=$(git config user.email)
R() { perl scripts/redact.pl; }
IMAGES="docker.io/library/postgres:18 docker.io/library/neo4j:4.4.42 docker.io/specterops/bloodhound:9.9.2 docker.io/library/python:3.11-slim"

if [ "$part" = host ] || [ "$part" = all ]; then
  {
    echo "# captured: $(date --iso-8601=seconds)"
    powershell.exe -NoProfile -Command '
      $c=Get-CimInstance Win32_Processor; $o=Get-CimInstance Win32_OperatingSystem; $s=Get-CimInstance Win32_ComputerSystem
      "CPU model      : $($c.Name.Trim())"
      "CPU cores      : $($c.NumberOfCores)"
      "CPU threads    : $($c.NumberOfLogicalProcessors)"
      "CPU base MHz   : $($c.MaxClockSpeed)"
      "RAM total bytes: $($s.TotalPhysicalMemory)"
      "RAM free bytes : $([int64]$o.FreePhysicalMemory*1024)  (Win32_OperatingSystem.FreePhysicalMemory at capture time)"
      "OS             : $($o.Caption) $($o.Version) build $($o.BuildNumber)"
      "Disks:"; Get-PhysicalDisk | ForEach-Object { "  $($_.FriendlyName) | MediaType=$($_.MediaType) | Bus=$($_.BusType) | SizeBytes=$($_.Size)" }
      $b=Get-CimInstance Win32_Battery; if ($b) { "Battery status : $($b.BatteryStatus) (2 = on AC power) charge=$($b.EstimatedChargeRemaining)%" }
      "Power scheme   : $((powercfg /getactivescheme) -join " ")"
      $ov=(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes").ActiveOverlayAcPowerScheme
      $name=@{"ded574b5-45a0-4f42-8737-46345c09c238"="Best performance";"00000000-0000-0000-0000-000000000000"="Balanced";"961cc777-2547-4f9d-8174-7d86181b8a7a"="Best power efficiency"}[$ov]
      "Power mode (AC overlay): $ov = $name"
      $w="$env:USERPROFILE\.wslconfig"; if (Test-Path $w) { "~/.wslconfig:"; Get-Content $w | % { "  $_" } }
      "WSL version:"; (wsl.exe --version) -replace "`0","" | ? { $_ -ne "" } | % { "  $_" }
    ' 2>&1 | tr -d '\r'
  } | R > "$D/hardware.txt"
  { echo "# captured: $(date --iso-8601=seconds)"; echo "## docker version"; docker version 2>&1
    echo; echo "## docker info"; docker info 2>&1
    echo; echo "## docker compose version"; docker compose version 2>&1; } | R > "$D/docker.txt"
  { echo "# captured: $(date --iso-8601=seconds)"; docker image ls --digests --no-trunc | head -1
    for i in $IMAGES; do docker image ls --digests --no-trunc "${i#docker.io/}" | tail -n +2; done
    echo; echo "## RepoDigests"; for i in $IMAGES; do docker image inspect --format '{{index .RepoTags 0}} {{json .RepoDigests}} created={{.Created}}' "${i#docker.io/}"; done; } 2>&1 | R > "$D/images.txt"
  docker compose config 2>&1 | R > "$D/compose.resolved.yml"
fi

if [ "$part" = neo4j ] || [ "$part" = all ]; then
  CS() { docker compose exec -T -e NEO4J_PASSWORD="$NEO4J_SECRET" graph-db cypher-shell -u neo4j --format plain; }
  {
    echo "# captured: $(date --iso-8601=seconds)"
    echo "## CALL dbms.components()"; echo "CALL dbms.components();" | CS
    echo; echo "## memory config"; echo "CALL dbms.listConfig() YIELD name, value WHERE name CONTAINS 'memory' RETURN name, value;" | CS
    echo; echo "## SHOW INDEXES"; echo "SHOW INDEXES;" | CS
    echo; echo "## SHOW CONSTRAINTS"; echo "SHOW CONSTRAINTS;" | CS
    echo; echo "## APOC / GDS procedures"; echo "CALL dbms.procedures() YIELD name WHERE name STARTS WITH 'apoc' OR name STARTS WITH 'gds' RETURN name;" | CS
    echo; echo "## JVM heap actually in use (JMX java.lang:type=Memory, bytes) + JVM args"
    echo 'CALL dbms.queryJmx("java.lang:type=Memory") YIELD attributes RETURN attributes.HeapMemoryUsage.value.properties AS heap; CALL dbms.queryJmx("java.lang:type=Runtime") YIELD attributes RETURN attributes.InputArguments.value AS jvm_args;' | CS
    echo; echo "## heap / pagecache as seen by the JVM (neo4j container)"
    docker compose exec -T graph-db sh -c 'ls /var/lib/neo4j/labs /var/lib/neo4j/plugins 2>&1; grep -E "^(dbms\.memory|#?dbms\.memory)" /var/lib/neo4j/conf/neo4j.conf 2>&1'
    echo; echo "## neo4j store dirs"; docker compose exec -T graph-db sh -c 'du -sb /data/databases/* /data/transactions/* 2>&1'
  } 2>&1 | R > "$D/neo4j.txt"
fi
echo "captured $phase/$part -> $D"; ls -l "$D"
