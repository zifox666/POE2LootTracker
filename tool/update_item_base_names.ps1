#requires -Version 7.0

param(
    [string]$BaseItemsUrl = "https://repoe-fork.github.io/poe2/base_items.json",
    [string]$TranslatorUrl = "https://raw.githubusercontent.com/soifow/poe-ninja-translator/main/src/data/dict.json",
    [string]$EnglishStaticUrl = "https://www.pathofexile.com/api/trade2/data/static",
    [string]$ChineseStaticUrl = "https://poe.game.qq.com/api/trade2/data/static",
    [string]$BaseNamesPath = (Join-Path $PSScriptRoot "..\tracker_host\Assets\item-base-names.json"),
    [string]$LocalizationPath = (Join-Path $PSScriptRoot "..\tracker_host\Assets\Localization\item-names.zh-CN.json"),
    [string]$OverridesPath = (Join-Path $PSScriptRoot "item-name-overrides.zh-CN.json"),
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$requestHeaders = @{ "User-Agent" = "POE2LootTracker item-name updater" }

function ConvertTo-SortedJson([System.Collections.IDictionary]$Values) {
    $keys = [string[]]$Values.Keys
    [Array]::Sort($keys, [StringComparer]::Ordinal)
    $sorted = [ordered]@{}
    foreach ($key in $keys) {
        $sorted[$key] = $Values[$key]
    }
    return ($sorted | ConvertTo-Json -Depth 3) + [Environment]::NewLine
}

$baseSource = Invoke-RestMethod -Uri $BaseItemsUrl -Headers $requestHeaders
$baseNames = @{}
foreach ($property in $baseSource.PSObject.Properties) {
    $metadataPath = $property.Name
    $item = $property.Value
    $name = [string]$item.name
    if ($metadataPath.StartsWith("Metadata/Items/", [StringComparison]::Ordinal) -and
        [string]$item.release_state -eq "released" -and
        -not [string]::IsNullOrWhiteSpace($name)) {
        $baseNames[$metadataPath] = $name.Trim()
    }
}
if ($baseNames.Count -eq 0) {
    throw "RePoE returned no released item base names."
}

$translations = @{}
$existing = Get-Content -LiteralPath $LocalizationPath -Raw | ConvertFrom-Json -AsHashtable
foreach ($entry in $existing.GetEnumerator()) {
    if (-not [string]::IsNullOrWhiteSpace([string]$entry.Key) -and -not [string]::IsNullOrWhiteSpace([string]$entry.Value)) {
        $translations[([string]$entry.Key).Trim()] = ([string]$entry.Value).Trim()
    }
}

# This comprehensive item dictionary is generated from poe2db's cn/tw pages by poe-ninja-translator.
$translatorResponse = Invoke-RestMethod -Uri $TranslatorUrl -Headers $requestHeaders
$translator = if ($translatorResponse -is [string]) { $translatorResponse | ConvertFrom-Json -AsHashtable } else { $translatorResponse }
if ($null -eq $translator.categories -or $null -eq $translator.categories.names -or $null -eq $translator.categories.baseTypes) {
    throw "The poe-ninja-translator dictionary is missing item-name categories."
}
foreach ($categoryName in @("names", "baseTypes")) {
    foreach ($entry in $translator.categories[$categoryName].GetEnumerator()) {
        $chinese = [string]$entry.Value.cn
        if (-not [string]::IsNullOrWhiteSpace([string]$entry.Key) -and -not [string]::IsNullOrWhiteSpace($chinese)) {
            $translations[([string]$entry.Key).Trim()] = $chinese.Trim()
        }
    }
}

# GGG's international and Tencent trade endpoints share stable IDs for static economy items.
$englishStatic = Invoke-RestMethod -Uri $EnglishStaticUrl -Headers $requestHeaders
$chineseStatic = Invoke-RestMethod -Uri $ChineseStaticUrl -Headers $requestHeaders
$englishById = @{}
$chineseById = @{}
foreach ($group in $englishStatic.result) {
    foreach ($entry in $group.entries) {
        if (-not [string]::IsNullOrWhiteSpace([string]$entry.id)) { $englishById[[string]$entry.id] = [string]$entry.text }
    }
}
foreach ($group in $chineseStatic.result) {
    foreach ($entry in $group.entries) {
        if (-not [string]::IsNullOrWhiteSpace([string]$entry.id)) { $chineseById[[string]$entry.id] = [string]$entry.text }
    }
}
$officialPairCount = 0
foreach ($id in $englishById.Keys) {
    if ($chineseById.ContainsKey($id) -and
        -not [string]::IsNullOrWhiteSpace($englishById[$id]) -and
        -not [string]::IsNullOrWhiteSpace($chineseById[$id])) {
        $translations[$englishById[$id].Trim()] = $chineseById[$id].Trim()
        $officialPairCount++
    }
}
if ($officialPairCount -eq 0) {
    throw "The official trade endpoints returned no matching localized static items."
}

$overrides = Get-Content -LiteralPath $OverridesPath -Raw | ConvertFrom-Json -AsHashtable
foreach ($entry in $overrides.GetEnumerator()) {
    if (-not [string]::IsNullOrWhiteSpace([string]$entry.Key) -and -not [string]::IsNullOrWhiteSpace([string]$entry.Value)) {
        $translations[([string]$entry.Key).Trim()] = ([string]$entry.Value).Trim()
    }
}

$baseJson = ConvertTo-SortedJson $baseNames
$localizationJson = ConvertTo-SortedJson $translations
$resolvedBasePath = [IO.Path]::GetFullPath($BaseNamesPath)
$resolvedLocalizationPath = [IO.Path]::GetFullPath($LocalizationPath)

if ($Check) {
    if (-not [IO.File]::Exists($resolvedBasePath) -or [IO.File]::ReadAllText($resolvedBasePath) -ne $baseJson) {
        throw "Item base-name resource is out of date: $resolvedBasePath"
    }
    if (-not [IO.File]::Exists($resolvedLocalizationPath) -or [IO.File]::ReadAllText($resolvedLocalizationPath) -ne $localizationJson) {
        throw "Chinese item-name resource is out of date: $resolvedLocalizationPath"
    }
} else {
    [IO.File]::WriteAllText($resolvedBasePath, $baseJson, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($resolvedLocalizationPath, $localizationJson, [Text.UTF8Encoding]::new($false))
}

$coveredPaths = @($baseNames.Values | Where-Object { $translations.ContainsKey([string]$_) }).Count
$coverage = [Math]::Round(100 * $coveredPaths / $baseNames.Count, 1)
$action = if ($Check) { "Verified" } else { "Wrote" }
Write-Host "$action $($baseNames.Count) base paths and $($translations.Count) Chinese names; $coveredPaths paths covered ($coverage%)."
