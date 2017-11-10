# ExtractTransformInflux
This script allows to extract data stored in an Influx time series measurement into a CSV file. There is an option to replace existing tag values with new values. The resulting CSV file can be exported back to another Influx Measurement or updaloded to same one, and old series can be dropped.

The ideal option would have been to have a simple `update tag value` command in Influxdb, but Influx design does not support such a feature at this time. Ref:  [#3904](https://github.com/influxdata/influxdb/issues/3904). Hence the need for this script.

Copyright: mvadu@adystech
license: MIT

#### SYNTAX
    ExtractTransformInflux.ps1 [-influxBaseUrl] <String> [-measurement] <String> [[-oldTags] <String>] [[-newTags] <String>] [[-additionalFilter]
    <String>] [[-batchSize] <Int32>] [[-outFile] <String>] [[-precision] <String>] [[-outtype] <String>] [[-timeformat] <String>] [<CommonParameters>]

#### PARAMETERS
#####    -influxBaseUrl <String>
        URL for the Influxdb query entry point (usually 8086 port), include the DB name as well e.g. "http://localhost:8086/query?db=InfluxerDB"

#####    -measurement <String>
        measurment to query from

#####    -oldTags <String>
        List of tags and their values to be replaced. Usage Pattern: <Tag=Value>. Separate multiple tags by a ;. e.g. "AppName=App1;Release=Beta". Optional parameter.

#####    -newTags <String>
        List of tags and their values to replace with. Usage Pattern: <Tag=Value>. Separate multiple tags by a ;. e.g. "AppName=MyApplication;Release=Pre_Beta". Mandatory if -oldTags is specified.

#####    -additionalFilter <String>
        Filters to restrict the points/series returned. Optional, but recommended

#####    -batchSize <Int32>
        Influx chunk size, defaults to 10000

#####    -outFile <String>
        Output file name, defaults to  ".\InfluxDump.csv"

#####    -precision <String>
        output precision, defaults to  seconds

#####    -outtype <String>
        output time format : text - logs in local system locale, epoch will use the epoch at $precison, Binary will be the .Net DateTIme Binary representation, defaults to text

#####    -timeformat <String>
        output time format when the -outtype is text, default will be upto micro second precision yyyy-MM-dd-hh.mm.ss.ffffff

### Usage
```powershell
.\ExtractTransformInflux.ps1 -influxBaseUrl "http://localhost:8086/query?db=TestDB" -measurement "MyMeasurement"  -oldTags "AppName=App1;Release=Beta" -newTags "AppName=MyApplication;Release=Pre_Beta"
```
