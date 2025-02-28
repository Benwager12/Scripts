Param (
	[switch] $SillyTavern,
    [switch] $Quiet,
    [int] $DebugMode=0,
    [int] $ContextLength=2048,
		
    [string] $webhookUrl="",
	[string] $webhookFormat="",

    [string] $HordeInfo="{}",

    [string] $Model
)

$Horde = $HordeInfo -ne "{}"
$Models = Get-ChildItem -Path .\Models | Where-Object {! $_.PSIsContainer}

if ($Horde) {
    Write-Host "Horde mode enabled."
}

if ($Models.Count -eq 0) {
    Write-Host "No models found in the Models folder."
    Start-Sleep -Seconds 3
    exit
}


$chosenModel = 1

if ($Models.Count -gt 1) {
    Write-Output "================================================="
    for ($modelIndex = 1; $modelIndex -le $Models.Count; $modelIndex++) {
        Write-Host "$($modelIndex). $($Models[$modelIndex - 1].BaseName)"
    }
    Write-Host "================================================="
    $chosenModel = Read-Host "Choose a model"
    if ($chosenModel -lt 1 -or $chosenModel -gt $Models.Count) {
        Write-Host "Invalid model choice."
        Start-Sleep -Seconds 3
        exit
    }
}

Write-Host "Launching model $($Models[$chosenModel - 1].BaseName)."

if ($Horde -and $HordeInfo -eq "{}") {
    Write-Host "Horde info is empty."
    Start-Sleep -Seconds 3
    exit
}

$koboldParams = @(
    "--model",
    "$($Models[$chosenModel - 1].FullName)"
)

if ($ContextLength -ne 2048) {
    $koboldParams += "--contextlength"
    $koboldParams += $ContextLength
}

if ($DebugMode) {
    $koboldParams += "--debug"
}

if ($Horde -and $HordeInfo -ne "{}") {
    $horde_json = $HordeInfo | ConvertFrom-Json
    if ($null -eq $horde_json) {
        Write-Host "Invalid horde info."
        Start-Sleep -Seconds 3
        exit
    }
    # Check if horde_info contains values for workername and key
    if ($null -eq $horde_json.workername -or $null -eq $horde_json.key) {
        Write-Host "Invalid horde info. (Needs workername and key)"
        Start-Sleep -Seconds 3
        exit
    }

    $modelName = $Models[$chosenModel - 1].BaseName -replace "(.*)([-|\.]Q\d.*)", '$1'
    $modelName = $modelName.replace("-", " ")
    
    $koboldParams += @(
        "--hordemodelname",
        $modelName,
        "--hordeworkername",
        $horde_json.workername,
        "--hordekey",
        $horde_json.key
    )
}

if ($Quiet) {
    $koboldParams += "--quiet"
}

wt --window 0 -p "Windows Terminal" "$pwd\koboldcpp.exe" @koboldParams


if ($webhookUrl -eq "" -and $webhookFormat -ne "") {
		Write-Host "A webhook format is set but the webhook URL is not."
		Start-Sleep -Seconds 3
		exit
}

if ($webhookUrl -ne "" -and $webhookFormat -eq "") {
		Write-Host "A webhook URL is set but the format is not."
		Start-Sleep -Seconds 3
		exit
}

if (!$webhookUrl -eq "") {
	if ($webhookFormat -Match "{ngrok}") {
		$response = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels"
		$webhookFormat.replace("{ngrok}", $response.tunnels.public_url)
	}
	if ($webhookFormat -Match "{local_ip}") {
		$MyIP=(Get-NetIPAddress | Where-Object {$_.AddressState -eq "Preferred" -and $_.ValidLifetime -lt "24:00:00"}).IPAddress
		$webhookFormat.replace("{local_ip}", $MyIP)
	}
    Invoke-RestMethod -Uri $WebhookUrl -Method Post -ContentType "application/json" -Body (@{content = $webhookFormat})
}

if ($SillyTavern) {
    wt --window 0 -p "Windows Terminal" "$pwd\SillyTavern\UpdateAndStart.bat"
}