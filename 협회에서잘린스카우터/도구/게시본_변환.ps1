# 게시본 변환 — 원고/*.md 를 문피아 붙여넣기용 게시/*.txt 로 바꾼다
#
# 원본은 항상 원고/ 다. 게시/ 는 생성물이므로 손으로 고치지 않는다.
# 원고를 고친 뒤 이 스크립트를 다시 돌린다.
#
# 변환 규칙
#   1. 첫 줄의 `# N화 — 제목` 을 뺀다. 제목은 문피아 제목 칸에 따로 넣는다
#   2. 코드펜스(```) 줄을 지우고 안쪽 [잠재 감정] 표기는 짧은 행으로 남긴다
#   3. 마크다운 굵게 표식(**)을 뗀다. 위치는 회차목록.md 에 남긴다
#   4. 장면 구분 기호 `*` 는 그대로 둔다. 마크업이 아니라 본문 기호다
#   5. 빈 줄은 하나로 맞추고 앞뒤 빈 줄을 없앤다
#
# 출력은 UTF-8(BOM 없음) + CRLF 다. BOM을 넣으면 전체 선택해 붙여넣을 때 보이지 않는 글자가
#
# PowerShell 5.1에서 돈다. 버전 요구 줄을 넣지 않는다.

[CmdletBinding()]
param(
    # 변환할 회차. 비우면 원고/ 에 있는 전부
    [int[]]$Chapters
)

$ErrorActionPreference = 'Stop'

$workRoot   = Split-Path -Parent $PSScriptRoot
$manuscript = Join-Path $workRoot '원고'
$outDir     = Join-Path $workRoot '게시'

if (-not (Test-Path $manuscript)) { throw "원고 폴더가 없다: $manuscript" }
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# 본문 맨 앞에 섞여 들어갈 수 있다. 메모장은 BOM 없이도 UTF-8을 읽는다.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Get-ChapterNumbers {
    if ($Chapters) { return $Chapters | Sort-Object }
    Get-ChildItem -Path $manuscript -Filter '???.md' |
        ForEach-Object { [int]($_.BaseName) } |
        Sort-Object
}

# 플랫폼 표시값과 비교하기 위한 글자 수. 본문 공백 포함, 줄바꿈 제외.
function Measure-Body([string]$text) {
    $flat = $text -replace '[\r\n]', ''
    $flat.Length - [regex]::Matches($flat, '[\uD800-\uDBFF][\uDC00-\uDFFF]').Count
}

$rows = @()
$boldSpots = @()

foreach ($n in Get-ChapterNumbers) {
    $src = Join-Path $manuscript ('{0:D3}.md' -f $n)
    if (-not (Test-Path $src)) { Write-Warning ('{0:D3}.md 가 없다. 건너뛴다.' -f $n); continue }

    $lines = ([System.IO.File]::ReadAllText($src) -replace "`r`n", "`n") -split "`n"

    # 제목 줄에서 회차 제목을 뽑는다. 이전 형식의 상태 표식도 호환하여 뗀다
    $title = ''
    if ($lines[0] -match '^#\s+(.*)$') {
        $title = ($Matches[1] -replace '\s*\((초안|확정)\)\s*$', '').Trim()
        $lines = $lines[1..($lines.Count - 1)]
    } else {
        Write-Warning ('{0:D3}: 첫 줄이 제목 형식이 아니다. 제목을 빼지 않았다.' -f $n)
    }

    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        if ($line -match '^\s*(```|~~~)') { continue }   # 펜스 줄 제거

        if ($line -match '\*\*') {
            $boldSpots += [pscustomobject]@{
                화   = ('{0:D3}' -f $n)
                본문 = ($line -replace '\*\*', '')
            }
        }
        $out.Add(($line -replace '\*\*', ''))
    }

    # 빈 줄 정리: 연속 빈 줄을 하나로, 앞뒤 빈 줄 제거
    $body = ($out -join "`n")
    $body = $body -replace "`n{3,}", "`n`n"
    $body = $body.Trim("`n")

    $dst = Join-Path $outDir ('{0:D3}.txt' -f $n)
    $postedText = $body -replace "`n", "`r`n"
    if (-not (Test-Path -LiteralPath $dst) -or
        [System.IO.File]::ReadAllText($dst) -cne $postedText) {
        [System.IO.File]::WriteAllText($dst, $postedText, $utf8NoBom)
    }

    $rows += [pscustomobject]@{
        화       = ('{0:D3}' -f $n)
        제목     = $title
        제목만   = ($title -replace '^\s*\d+화\s*[—\-–]\s*', '')
        글자수   = Measure-Body $body
        감정표기 = ([regex]::Matches($body, '(?m)^\[\s')).Count
    }
}

# 회차목록 — 문피아 등록 칸에 그대로 옮겨 쓰는 용도
$md = New-Object System.Collections.Generic.List[string]
$md.Add('# 게시 회차 목록 (생성물)')
$md.Add('')
$md.Add(('생성: {0} / `도구/게시본_변환.ps1` 출력. 손으로 고치지 않는다. 원본은 `원고/` 다.' -f (Get-Date -Format 'yyyy-MM-dd HH:mm')))
$md.Add('')
$md.Add('## 작품 등록 정보')
$md.Add('')
$md.Add('근거: [10_등록정보](../설정집/10_등록정보.md) (2026-09-30 확정). 아래 값을 등록 칸에 그대로 옮긴다.')
$md.Add('')
$md.Add('**제목** (26자)')
$md.Add('')
$md.Add('    협회에서 잘린 스카우터가 F급만 데려갔더니 전부 S급')
$md.Add('')
$md.Add('**소개글** — 주력안 (43자)')
$md.Add('')
$md.Add('    협회에서 잘렸다. 사람을 기계로 재기 시작한 날.')
$md.Add('    그 기계가 못 재는 걸 나는 본다.')
$md.Add('')
$md.Add('예비로 확장안(60자, 공명까지 넣는 3행)과 초단문안(24자)이 10_등록정보에 있다. 연재 초기 반응을 보고 교체하는 카드다.')
$md.Add('')
$md.Add('**태그** — 6개')
$md.Add('')
$md.Add('    현대판타지 · 헌터 · 사이다 · 각성 · 성장 · 회사원')
$md.Add('')
$md.Add('7개까지 허용되면 `힐링`이 1순위 추가 후보다. `나혼자` `먼치킨` `천재` `재벌` `탑등반물`은 일부러 뺐다(이유는 10_등록정보).')
$md.Add('')
$md.Add('## 회차')
$md.Add('')
$md.Add('| 화 | 회차 제목 | 제목만 | 글자수 | [잠재 감정] 표기 | 파일 |')
$md.Add('|---|---|---|---:|---:|---|')
foreach ($r in $rows) {
    $md.Add(('| {0} | {1} | {2} | {3:N0} | {4} | [{0}.txt]({0}.txt) |' -f $r.화, $r.제목, $r.제목만, $r.글자수, $r.감정표기))
}
$md.Add('')
$md.Add(('합계 {0:N0}자 / {1}화 / 평균 {2:N0}자' -f (($rows | Measure-Object 글자수 -Sum).Sum, $rows.Count, [math]::Round((($rows | Measure-Object 글자수 -Sum).Sum) / $rows.Count))))
$md.Add('')
$md.Add('글자수는 본문 공백 포함, 줄바꿈 제외다. 문피아 표시값과 다를 수 있으므로 첫 회차 등록 때 실제 표시값을 적어 둔다.')
$md.Add('')

if ($boldSpots.Count) {
    $md.Add('## 굵게 처리 위치')
    $md.Add('')
    $md.Add('원고에서 굵게 표시된 줄이다. 변환본에서는 표식을 뗐다. 에디터에서 굵게를 주고 싶으면 아래 줄을 찾아 적용한다.')
    $md.Add('')
    foreach ($b in $boldSpots) { $md.Add(('- {0}: {1}' -f $b.화, $b.본문)) }
    $md.Add('')
}

$md.Add('## 붙여넣을 때')
$md.Add('')
$md.Add('- 문피아가 회차 번호를 따로 붙이면 제목만 열을, 번호까지 직접 넣어야 하면 회차 제목 열을 쓴다. 원고 회차 제목에는 상태 표식을 붙이지 않는다.')
$md.Add('- [잠재 감정] 표기는 여러 줄이 붙어 있어야 한다. 에디터가 줄마다 문단 간격을 넣으면 그 안쪽은 Shift+Enter로 줄을 바꾼다.')
$md.Add('- 장면 구분 기호 `*` 는 본문 기호라서 그대로 둔다.')
$md.Add('- 첫 회차를 올린 뒤 문피아가 표시하는 글자 수를 위 표와 비교해 기록한다.')
$md.Add('')

[System.IO.File]::WriteAllText(
    (Join-Path $outDir '회차목록.md'),
    (($md -join "`n") -replace "`n", "`r`n"),
    (New-Object System.Text.UTF8Encoding($false))
)

$rows | Format-Table -AutoSize
Write-Output ('게시본 {0}편을 {1} 에 썼다.' -f $rows.Count, $outDir)
