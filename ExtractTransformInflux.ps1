<#
.SYNOPSIS
This script allows to extract data stored in an Influx time series measurement into a CSV file.
.DESCRIPTION
This script allows to extract data stored in an Influx time series measurement into a CSV file. There is an option to replace existing tag values with new values. The resulting CSV file can be exported back to another Influx Measurement or updaloded to same one, and old series can be dropped.
Copyright: mvadu@adystech
license: MIT
.EXAMPLE
.\ExtractTransformInflux.ps1 -influxBaseUrl "http://localhost:8086/query?db=TestDB" -measurement "MyMeasurement"  -oldTags "AppName=App1;Release=Beta" -newTags "AppName=MyApplication;Release=Pre_Beta"
#>

[CmdletBinding()]
param (
    #URL for the Influxdb query entry point (usually 8086 port), include the DB name as well e.g. "http://localhost:8086/query?db=InfluxerDB" 
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $influxBaseUrl,
    
    #measurment to query from
    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string] $measurement ,

    #List of tags and their values to be replaced. Usage Pattern: <Tag=Value>. Separate multiple tags by a ;. e.g. "AppName=App1;Release=Beta". Optional parameter. 
    [string] $oldTags,

    #List of tags and their values to replace with. Usage Pattern: <Tag=Value>. Separate multiple tags by a ;. e.g. "AppName=MyApplication;Release=Pre_Beta". Mandatory if -oldTags is specified. 
    [string] $newTags,

    #Filters to restrict the points/series returned. Optional, but recommended 
    [string] $additionalFilter,
    
    #Influx chunk size, defaults to 10000
    [int] $batchSize = 10000,

    #Output file name, defaults to  ".\InfluxDump.csv"
    [string]$outFile = ".\InfluxDump.csv",

    #output precision, defaults to  seconds
    [ValidateSet("ns","u","ms","s","m","h")]
    [string] $precision = "s",

    #output time format : text - logs in local system locale, epoch will use the epoch at $precison, Binary will be the .Net DateTIme Binary representation, defaults to text
    [ValidateSet("text","epoch","binary")]
    [string] $outtype = "text",

    #output time format when the -outtype is text, default will be upto micro second precision yyyy-MM-dd-hh.mm.ss.ffffff
    [string] $timeformat = "yyyy-MM-dd-hh.mm.ss.ffffff"
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
    $([regex] "(?<tag>.*?)=(?<value>.*?);").Matches($oldTags) | ForEach-Object {$oldTagSet.Add([PSCustomObject]@{Index=$index++; Tag = $_.groups["tag"].Value ; Value =  $_.groups["value"].Value })}

    if(!$newTags.EndsWith(";")) { $newTags = $newTags + ";" }
    $newTagSet = New-Object Collections.Generic.List[PSCustomObject]
    $index = 0
    $([regex] "(?<tag>.*?)=(?<value>.*?);").Matches($newTags) |  ForEach-Object {$newTagSet.Add([PSCustomObject]@{Index=$index++; Tag = $_.groups["tag"].Value ; Value =  $_.groups["value"].Value })}

    if($newTagSet.Count -ne $oldTagSet.Count){
        Write-Host "Number of Tags to replace do not match with new set of tags provided"
        exit
    }
}

process{
    $recordsProcessed = 0

    $tagFilter = [string]::Join(" OR ",@($oldTagSet | ForEach-Object { "$($_.Tag) = '$($_.Value)'"}))
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

        $query = "$influxBaseUrl&epoch=$precision&q=select * from $measurement $whereClaus limit $batchSize offset $recordsProcessed"

        $response = invoke-webrequest $query -UseBasicParsing

        $influxData = $response.Content | ConvertFrom-Json

        
        if($influxData.results[0].series.Count -gt 1) {
            write-host "The query is resulting in more than one series"
            exit
        }
        $series = $influxData.results[0].series[0]

        for ($row = 0; $row -lt $series.values.Count; $row++){
            $point = [ordered]@{}
            for ($col = 0; $col -lt $series.Columns.Count; $col++) {
                $point.Add($series.Columns[$col], $series.Values[$row][$col])
            }
            $points.Add([pscustomobject]$point)
        }
        Write-Progress -activity "Processing" -status "Points Processed: $($recordsProcessed + $row)"

        if($outtype -ne "epoch") {
            $origin = (New-Object -Type DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, 0,Utc) #[datetime]::FromBinary(5233041986427387904)
            switch -Exact ($precision) {
                "ns" {$points | ForEach-Object {$_.Time = $origin.AddTicks($_.Time/100)}}
                "u" {$points | ForEach-Object {$_.Time = $origin.AddTicks($_.Time * [TimeSpan]::TicksPerMillisecond * 1000)}}
                "ms" {$points | ForEach-Object {$_.Time = $origin.AddMilliseconds($_.Time )}}
                "s" {$points | ForEach-Object {$_.Time = $origin.AddSeconds($_.Time)}}
                "m" {$points | ForEach-Object {$_.Time = $origin.AddMinutes($_.Time)}}
                "h" {$points | ForEach-Object {$_.Time = $origin.AddHours($_.Time)}}
            }
            switch($outtype) {
                "text" {$points | ForEach-Object {$_.Time = $_.Time.ToString($timeformat)}}
                "binary" {$points | ForEach-Object {$_.Time = $_.Time.ToBinary()}}
            }
        }

        foreach($tag in $oldTagSet){
            $points | Where-Object { $_.($tag.Tag) -eq $tag.Value } | ForEach-Object { $_.($tag.Tag) = $newTagSet[$tag.Index].Value}
        }

        $recordsProcessed = $recordsProcessed + $row
        $points | Export-Csv -NoTypeInformation -Path $outFile -Encoding ascii -Append        
        $points.clear()

    } until($row -lt $batchSize)
}
end{
    Write-Host "$([datetime]::now.tostring()) Done with process, extracted $recordsProcessed points"
}
