[CmdletBinding()]
param (
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $influxBaseUrl,
    
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $measurement ,

    [string] $oldTags,

    [string] $newTags,

    [string] $additionalFilter,
    
    [int] $batchSize = 10000,

    [string]$outFile = ".\InfluxDump.csv"

)

begin{
    Write-Host "$([datetime]::now.tostring()) Starting $(split-path -Leaf $MyInvocation.MyCommand.Definition ) process"
    
    $pwd = split-path -parent $MyInvocation.MyCommand.Definition

    if(([string]::IsNullOrEmpty($oldTags) -and -not [string]::IsNullOrEmpty($newTags)) -or (-not [string]::IsNullOrEmpty($oldTags) -and [string]::IsNullOrEmpty($newTags))){
        throw "If 'oldTags' is specified then you new need to specify 'newTags' as well (and visa versa).!!"
        exit
    }
 
   
    if(!$oldTags.EndsWith(";")) { $oldTags = $oldTags + ";" }
    $oldTagSet = New-Object Collections.Generic.List[PSCustomObject]
    $index = 0
    $([regex] "(?<tag>.*?)=(?<value>.*?);").Matches($oldTags) | foreach {$oldTagSet.Add([PSCustomObject]@{Index=$index++; Tag = $_.groups["tag"].Value ; Value =  $_.groups["value"].Value })}

    if(!$newTags.EndsWith(";")) { $newTags = $newTags + ";" }
    $newTagSet = New-Object Collections.Generic.List[PSCustomObject]
    $index = 0
    $([regex] "(?<tag>.*?)=(?<value>.*?);").Matches($newTags) |  foreach {$newTagSet.Add([PSCustomObject]@{Index=$index++; Tag = $_.groups["tag"].Value ; Value =  $_.groups["value"].Value })}

    if($newTagSet.Count -ne $oldTagSet.Count){
        Write-Host "Number of Tags to replace do not match with new set of tags provided"
        exit
    }
    
  # Function EpochConverter{
  #     [CmdletBinding()]
  #     param (
  #         [parameter(Mandatory=$true)]
  #         [ValidateNotNullOrEmpty()]
  #         [long] $epoch
  #     )
  #     #(New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0,Utc).ToBinary()
  #     $origin = [datetime]::FromBinary(5233041986427387904).AddTicks($epoch/100)
  # }
}

process{
    $recordsProcessed = 0

    $tagFilter = [string]::Join(" OR ",@($oldTagSet | foreach { "$($_.Tag) = '$($_.Value)'"}))
    $whereClaus = if ($oldTagSet.count -gt 0 -and -not [string]::IsNullOrEmpty($additionalFilter)){
        "where $tagFilter AND $additionalFilter"
    } elseif ($oldTagSet.count -gt 0) {
        "where $tagFilter "
    } elseif (-not [string]::IsNullOrEmpty($additionalFilter)){
        "where $additionalFilter "
    }
     
    $points = New-Object Collections.Generic.List[PSCustomObject]
    do{
        Write-Progress -activity "Extracting" -status "Points Processed: $recordsProcessed"

        $query = "$influxBaseUrl&epoch=ns&q=select * from $measurement $whereClaus limit $batchSize offset $recordsProcessed"

        $response = invoke-webrequest $query

        $influxData = $response.Content | ConvertFrom-Json

        
        if($influxData.results[0].series.Count -gt 1) {
            write-host "The query is resulting in more than one series"
            exit
        }
        $series = $influxData.results[0].series[0]

        $origin = [datetime]::FromBinary(5233041986427387904)
        
        for ($row = 0; $row -lt $series.values.Count; $row++){
            $point = [ordered]@{}
            for ($col = 0; $col -lt $series.Columns.Count; $col++) {
                $point.Add($series.Columns[$col], $series.Values[$row][$col])
            }
            $points.Add([pscustomobject]$point)
        }
        Write-Progress -activity "Processing" -status "Points Processed: $($recordsProcessed + $row)"

        $points | foreach {$_.Time = $origin.AddTicks($_.Time/100)}
        foreach($tag in $oldTagSet){
            $points | where { $_.($tag.Tag) -eq $tag.Value } | foreach { $_.($tag.Tag) = $newTagSet[$tag.Index].Value}
        }

        $recordsProcessed = $recordsProcessed + $row
        $points | Export-Csv -NoTypeInformation -Path $outFile -Encoding ascii -Append        
        $points.clear()

    } until($row -lt $batchSize)
}
end{
    Write-Host "$([datetime]::now.tostring()) Done with process, extracted $recordsProcessed points"
}
