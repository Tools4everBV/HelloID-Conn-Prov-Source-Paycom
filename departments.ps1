$config = ConvertFrom-Json $configuration;

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; 
<#
$config = @{
    BaseUri = "https://api.paycomonline.net/v4/rest/index.php"
    SID = ""
    Token = ""
    PageSize = 500
}
#>
function Get-ObjectProperties 
{
    param ($Object, $Depth = 0, $MaxDepth = 10)
    $OutObject = @{};

    foreach($prop in $Object.PSObject.properties)
    {
        if ($prop.TypeNameOfValue -eq "System.Management.Automation.PSCustomObject" -or $prop.TypeNameOfValue -eq "System.Object" -and $Depth -lt $MaxDepth)
        {
            $OutObject[$prop.Name] = Get-ObjectProperties -Object $prop.Value -Depth ($Depth + 1);
        }
        elseif ($prop.TypeNameOfValue -eq "System.Object[]") 
        {
            $OutObject[$prop.Name] = [System.Collections.ArrayList]@()
            foreach($item in $prop.Value)
            {
                $OutObject[$prop.Name].Add($item)
            }
        }
        else
        {
            $OutObject[$prop.Name] = "$($prop.Value)"
        }
    }
    return $OutObject;
}


$SID = $config.SID
$pageSize = $config.PageSize
$Token = $config.Token
$baseuri = $config.BaseUri + "/api/v1/cl/locations"

$pair = "{0}:{1}" -f $SID, $Token
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$bear_token = [System.Convert]::ToBase64String($bytes)
$headers = @{ Authorization = "Basic " + $bear_token };

$page = 0
$paging = $true
$locations = [System.Collections.ArrayList]@();


While($paging){

    
    $uri = $baseuri
    Write-Information "Retrieving $($baseuri) - Page $($page)"
    $response = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers  -ContentType 'application/json' -TimeoutSec 3600;
    if($response.data.count -lt $pageSize) {
        $paging = $false
    }
    $page++
    [void]$locations.AddRange($response.data);

}

Write-Information "Retrieved $($locations.count) Departments"

$counter = 0
foreach($location in $locations){
    $department = @{};
    $department = Get-ObjectProperties -Object $location
			
    $department['ExternalId'] = $location.locationid
    $department['DisplayName'] = $location.description

    Write-Output ($department | ConvertTo-Json -Depth 20);
    
}


