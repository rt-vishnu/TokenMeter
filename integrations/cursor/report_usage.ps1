param(
    [string]$Url = $env:PROMPT_PENNY_URL,
    [string]$ApiKey = $env:PROMPT_PENNY_API_KEY,
    [Parameter(Mandatory = $true)][string]$Model,
    [Parameter(Mandatory = $true)][int]$InputTokens,
    [Parameter(Mandatory = $true)][int]$OutputTokens,
    [string]$Source = "cursor",
    [string]$SessionId = ""
)

if (-not $Url) { $Url = "http://127.0.0.1:8765" }
if (-not $ApiKey) {
    Write-Error "Set PROMPT_PENNY_API_KEY environment variable or pass -ApiKey"
    exit 1
}

$body = @{
    model         = $Model
    input_tokens  = $InputTokens
    output_tokens = $OutputTokens
    source        = $Source
}
if ($SessionId) { $body.session_id = $SessionId }

$headers = @{
    "Authorization" = "Bearer $ApiKey"
    "Content-Type"  = "application/json"
}

$response = Invoke-RestMethod `
    -Uri "$($Url.TrimEnd('/'))/api/v1/usage" `
    -Method POST `
    -Headers $headers `
    -Body ($body | ConvertTo-Json)

$response | ConvertTo-Json -Depth 5
