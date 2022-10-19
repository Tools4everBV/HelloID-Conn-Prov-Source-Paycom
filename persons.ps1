[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; 
$config = ConvertFrom-Json $configuration;

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
$Token = $config.Token
$pageSize = $config.PageSize
$baseuri = $config.BaseUri + "/api/v1/employeeid?pagesize=" + $pageSize + "&page="
#$baseuri = $config.BaseUri + "/api/v1/newhireids"

$pair = "{0}:{1}" -f $SID, $Token
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$bear_token = [System.Convert]::ToBase64String($bytes)
$headers = @{ Authorization = "Basic " + $bear_token };

$page = 0
$paging = $true
$employees = [System.Collections.ArrayList]@();

$uri = $baseuri + $page
Write-Information "Retrieving $($baseuri)$($page)"

$response = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers  -ContentType 'application/json' -TimeoutSec 3600;

[void]$employees.AddRange($response.data);

Write-Information "Gathering Details for $($employees.count) Users"

$counter = 0
$page = 1
foreach($employee in $employees){
    $counter++
    $person = @{};
    
    $person = Get-ObjectProperties -Object $employee;
			
    $person['ExternalId'] = $employee.eecode
    $person['DisplayName'] = "$($employee.firstname) $($employee.lastname) ($($employee.eecode))";
    
    $person['Contracts'] = [System.Collections.ArrayList]@();
    $uri = $config.BaseUri + "/api/v1/employee/" + $employee.eecode

    $response = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers  -ContentType 'application/json' -TimeoutSec 3600;
    
    $customFieldsuri = $config.BaseUri + "/api/v1/employee/" + $employee.eecode + "/customfield"

    $responseCustomFields = Invoke-RestMethod -Method GET -Uri $customFieldsuri -Headers $headers  -ContentType 'application/json' -TimeoutSec 3600;

    
    $Object = $responseCustomFields.data[0]
 
    $custom = @{};
    foreach($prop in $Object.PSObject.properties)
    {
        if($prop.Value.description.Length -gt 0) {
            $custom["_" + $prop.Value.description.replace(" ","").replace("/","").replace("#","").replace("-","")] = $prop.Value.value;
        }
    }
    $person['CustomFields'] = [System.Collections.ArrayList]@();
    $person['CustomFields'] = $custom

    $contract =  @{};
    
    #[void]$contract.AddRange($response.data);
    $person['Contracts'] = $response.data.PsObject.BaseObject
    
    Write-Output ($person | ConvertTo-Json -Depth 20);
    if($counter -ge 100){
        $pageCount = $counter * $page
        Write-Information "Retrieved $($pageCount) Users"
        $counter = 0
        $page++
    }
 
    
}

Write-Information "Finished Retrieving Employees"
 