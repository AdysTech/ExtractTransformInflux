[CmdletBinding()]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $influxBaseUrl,
    
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $measurement ,

    [string[]] $tags,

    [string]$outFile = ".\InfluxDump.csv"    
)
    
function GetTagValues {
    param (
        [string] $query
    )
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")        
    $jsonserial = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer 
    #$jsonserial.MaxJsonLength  = 24MB # default is 2097152 
    try {
        $response = invoke-webrequest $query        
        #$influxData = $response.Content | ConvertFrom-Json
        $influxData = $jsonserial.DeserializeObject($response.Content )
    if ($influxData.results[0].series.Count -gt 1) {
        write-host "The query is resulting in more than one series"
        exit
    }
    write-output $influxData.results[0].series[0].values| foreach {$_[1]}
     }
    catch {
        write-Error "Error $($_.Exception.Message) at $($_.InvocationInfo.PositionMessage); Query: $query" 
    }
}

function QueryTagValues {
    param (
        [string] $baseQuery,
        [string[]] $tags,
        [hashtable] $filter
    )
    $output = [Collections.Generic.List[PSCustomObject]]::new()
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")        
    $jsonserial = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer 
    if($filter -ne $null){
        $filters = $filter.GetEnumerator().foreach{"$($_.Key)='$($_.value)'"} -join " and "
        $query = "$baseQuery with key=$($tags[0]) where $filters"
    } else {
        $query = "$baseQuery with key=$($tags[0])"
    }
    $values = GetTagValues $query
    if ($tags.Count -gt 1) {        
        foreach($value in $values) {            
            $filters = [ordered]@{}        
            if($filter -ne $null) {$filter.GetEnumerator().foreach{$filters.Add($_.Key,$_.value)}}
            $filters.Add($tags[0],$value)
            $out = @(QueryTagValues -baseQuery "$influxBaseUrl&epoch=ns&q=show tag values from $measurement" -tags ($tags | Select-Object -Skip 1) -filter $filters)
            $out.ForEach({$output.Add($_)})
        }
        Write-Output $output
        return
    }
    else {
        $out = [ordered]@{}        
        if($filter -ne $null) {$filter.GetEnumerator().foreach{$out.Add($_.Key,$_.value)}}
        $out.Add($tags[0],$values.Count)
        write-output $([PSCustomObject] $out)
        return
    }
}


Write-Verbose "$([datetime]::now.tostring()) Starting $(split-path -Leaf $MyInvocation.MyCommand.Definition ) process"    
$tagValues = QueryTagValues -baseQuery "$influxBaseUrl&epoch=ns&q=show tag values from $measurement" -tags $tags -filter $null
Write-Output $tagValues
Write-Verbose "$([datetime]::now.tostring()) Done with process, extracted $recordsProcessed points"
