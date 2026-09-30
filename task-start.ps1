#requires -Version 7.0
<#
읽기 전용 소설 작업 준비·분량 검사. 저장소 루트에서 ./task-start로 실행한다.
본문: 제목/줄바꿈/코드 펜스/강조 표식/장면 구분 표식을 제외하고 공백 포함.
코드 블록 안 감정 결과는 본문으로 센다. 바이트가 아닌 유니코드 문자 수다.
지원 원고 형식: H1 회차 제목, 일반 문단·대사, *, **강조**, `표기`, 코드 펜스.
결과 객체의 LengthPassed는 분량만 판정한다. 설정·문장은 AI가 직접 읽는다.
#>
[CmdletBinding()]
param(
    [ValidateSet('start', 'write', 'review')][string]$Mode = 'start',
    [ValidateRange(1, 999)][int[]]$Chapters,
    [ValidatePattern('^[^\\/:.]+$')][string]$Work = '협회에서잘린스카우터',
    [switch]$AsJson
)
$ErrorActionPreference = 'Stop'
$workRoot = Join-Path $PSScriptRoot $Work
if (-not (Test-Path -LiteralPath $workRoot -PathType Container)) {
    throw "작품 폴더가 없습니다: $Work"
}
$manuscriptRoot = Join-Path $workRoot '원고'
$targets = if ($Chapters) {
    @($Chapters | Sort-Object -Unique | ForEach-Object { Join-Path $manuscriptRoot ('{0:000}.md' -f $_) })
} else {
    @(Get-ChildItem -LiteralPath $manuscriptRoot -Filter '*.md' -File | Where-Object { $_.Name -match '^\d{3}\.md$' } | Sort-Object Name | ForEach-Object FullName)
}
$results = @(
    foreach ($target in $targets) {
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            [pscustomobject]@{ File = $target; Exists = $false; Characters = $null; LengthPassed = $false; PronounCandidates = @() }
            continue
        }
        $raw = Get-Content -LiteralPath $target -Raw -Encoding utf8
        $body = $raw -replace '(?m)^# [^\r\n]*(?:\r?\n|$)', ''
        $body = $body -replace '(?m)^\s*(```|~~~)[^\r\n]*(?:\r?\n|$)', ''
        $body = $body -replace '[\r\n`*]', ''
        $count = $body.Length - [regex]::Matches($body, '[\uD800-\uDBFF][\uDC00-\uDFFF]').Count
        $candidates = @()
        $lineNumber = 0
        foreach ($line in ($raw -split '\r?\n')) {
            $lineNumber++
            if ($line -match '(?<![가-힣A-Za-z])나는(?![가-힣A-Za-z])') {
                $candidates += [pscustomobject]@{ Line = $lineNumber; Text = $line }
            }
        }
        [pscustomobject]@{ File = $target; Exists = $true; Characters = $count; LengthPassed = ($count -ge 5500 -and $count -le 6000); PronounCandidates = $candidates }
    }
)
$report = [pscustomobject]@{
    Mode = $Mode
    Work = $Work
    ReadFirst = @('skill/INDEX.md', 'skill/working-rules.md', 'AGENTS.md', "$Work/README.md", "$Work/설정집/01~11", "$Work/구성/", '대상과 앞뒤 원고 및 git diff')
    Workflow = switch ($Mode) { 'write' { 'task-start → novel-write → novel-review → 허용 범위 수정·재검증' } 'review' { 'task-start → novel-review (점검만 요청은 수정 금지)' } default { 'task-start → 사용자 요청에 따라 집필 또는 검증' } }
    Manuscripts = $results
    Note = '파일 목록·분량만 확인했습니다. 규칙 읽기, 설정·문장 검증과 집필은 AI가 수행해야 합니다.'
}
if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
} else {
    Write-Output "작품: $Work / 작업: $Mode"
    Write-Output $report.Workflow
    Write-Output ('먼저 읽기: ' + ($report.ReadFirst -join ', '))
    foreach ($result in $results) {
        $fileName = Split-Path -Leaf $result.File
        if (-not $result.Exists) { Write-Output "$fileName : 미작성"; continue }
        $verdict = if ($result.LengthPassed) { '분량 충족' } else { '분량 조정 필요' }
        Write-Output ("{0} : {1}자 / {2} / 나는 후보 {3}줄(직접 문맥 확인)" -f $fileName, $result.Characters, $verdict, $result.PronounCandidates.Count)
        foreach ($candidate in $result.PronounCandidates) { Write-Output ("  {0}: {1}" -f $candidate.Line, $candidate.Text) }
    }
    Write-Output $report.Note
}
if ($Mode -eq 'review' -and ($results.Count -eq 0 -or @($results | Where-Object { -not $_.LengthPassed }).Count -gt 0)) { exit 1 }
exit 0
