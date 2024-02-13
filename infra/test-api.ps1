param (
    [string]$apiUrl = 'https://apim-contoso.azure-api.net',
    [string]$apiSubscriptionKey = '12345',
    [ValidateSet('gpt-3.5-turbo', 'text-embedding-ada-002', 'text-embeddings-inference')]
    [string]$model = 'gpt-3.5-turbo',
    [string]$workloadName = 'contoso',
    [string]$apiUrlSuffix = '/api/v1' -f $workloadName
)

$completionsEndpoint = ""
$requestBodyString = ""

if ($model -eq 'gpt-3.5-turbo') {
    $completionsEndpoint = "{0}{1}/generate" -f $apiUrl, $apiUrlSuffix
    $requestBody = @{
        messages = @(
            @{
                role = "system"
                content = "You are a helpful AI assistant. You always try to provide accurate answers or follow up with another question if not."
            },
            @{
                role = "user"
                content = "What is the best way to get to London from Berlin?"
            }
        )
        max_tokens = 200
        temperature = 0.7
        top_p = 0.95
        frequency_penalty = 0
        presence_penalty = 0
    }
    $requestBodyString = $requestBody | ConvertTo-Json -Depth 10 -Compress
} elseif ($model -eq 'text-embedding-ada-002') {
    $completionsEndpoint = "{0}{1}/embed" -f $apiUrl, $apiUrlSuffix
    $requestBodyString = '{
        "input": "The food was delicious and the waiter...",
        "model": "text-embedding-ada-002",
        "encoding_format": "float"
      }'
} elseif ($model -eq 'text-embeddings-inference') {
    $completionsEndpoint = "{0}{1}/rerank" -f $apiUrl, $apiUrlSuffix
    $requestBodyString = '{"query":"What is Deep Learning?", "texts": ["Deep Learning is not...", "Deep learning is..."]}'
} else {
    throw "Model $model not supported"
}

$requestHeaders = @{
    "Ocp-Apim-Subscription-Key" = $apiSubscriptionKey
    "Content-Type" = "application/json"
}

Write-Host "Posting request with URI $completionsEndpoint and body $requestBodyString"
$apiManagementResponse = Invoke-WebRequest -Uri $completionsEndpoint -Headers $requestHeaders -Method POST -Body $requestBodyString -ContentType "application/json" -skipCertificateCheck
Write-Host "Response: $apiManagementResponse"

