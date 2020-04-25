This repo hosts scripts assisting in the Influxdb analytics, and data extraction needs. It currently supports two use cases:
1. [ExtractTransformInflux](#ExtractTransformInflux) Currently there is not a way to update the tags (like tag names, making a field a tag or a tag to filed) after the fact in InfluxDB. The ideal option would have been to have a simple `update tag value` command in Influxdb, but Influx design does not support such a feature at this time. Ref:  [#3904](https://github.com/influxdata/influxdb/issues/3904).

2. [show-InfluxTagCardinality](#show-InfluxTagCardinality)There is not an easy way to show the cascaded cardinality; for example you have a series1 with m unique values, and series2 with n unique values etc. there isn't a way to get how many unique values (cardinality) in series2 for each of the values in series1. Given the TSM structure the m*n is what drives lot of capacity needs for Influx. 


## ExtractTransformInflux
This script allows to extract data stored in an Influx time series measurement into a CSV file. There is an option to replace existing tag values with new values. The resulting CSV file can be exported back to another Influx Measurement or updaloded to same one, and old series can be dropped.

#### SYNTAX
    ExtractTransformInflux.ps1 [-influxBaseUrl] <String> [-measurement] <String> [[-oldTags] <String>] [[-newTags] <String>] [[-additionalFilter]
    <String>] [[-batchSize] <Int32>] [[-outFile] <String>] [[-precision] <String>] [[-outtype] <String>] [[-timeformat] <String>] [<CommonParameters>]

#### PARAMETERS
#####    -influxBaseUrl <String>
        URL for the Influxdb query entry point (usually 8086 port), include the DB name as well e.g. "http://localhost:8086/query?db=InfluxerDB"

#####    -measurement <String>
        measurement to query from

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
#### Extract & Transform
```powershell
.\ExtractTransformInflux.ps1 -influxBaseUrl "http://localhost:8086/query?db=TestDB" -measurement "MyMeasurement"  -oldTags "AppName=App1;Release=Beta" -newTags "AppName=MyApplication;Release=Pre_Beta"
```

#### Insert back to Influx
Once downloaded data can then be inserted back into Influx using the [Influxer](https://github.com/AdysTech/Influxer) using command link this
```
1. Generate a column config
 influxer.exe -format Generic -input InfluxDump.csv -TimeFormat "yyyy-MM-dd-hh.mm.ss.ffffff" -Precision Microseconds -splitter "," /export /autolayout > influxer.config

2. Customize the config as needed - edit the retention policy name, table name etc

3. influxer.exe -format Generic -input InfluxDump.csv -config influxer.config 

```

## show-InfluxTagCardinality
This script calculates the [tag value cardinality](https://docs.influxdata.com/influxdb/v1.7/query_language/spec/#show-tag-values-cardinality). InfluxDB native implementation gives the value cardinality per tag key. But in real world situations we might want to know the unique values of one tag given each unique values of another tag. e.g. assume we track no sessions served by various docker instances, source IP, and geo location. So if we have to calculate number of unique IP address per geo location, default influx is not straight forward. This script comes handy in those situations.

#### SYNTAX
    show-InfluxTagCardinality.ps1 [-influxBaseUrl] <String> [-measurement] <String> [[-tags] <String[]>]

#### PARAMETERS
#####    -influxBaseUrl <String>
        URL for the Influxdb query entry point (usually 8086 port), include the DB name as well e.g. "http://localhost:8086/query?db=InfluxerDB"

#####    -measurement <String>
        measurment to query from

#####    -tags <String[]>
        array of tags which should be considered for cardinality calculation. 

### Usage
```powershell
.\show-InfluxTagCardinality.ps1 -influxBaseUrl "http://localhost:8086/query?db=TestDB" -measurement "MyMeasurement"  -tags @("GeoLocation,IP_Address")
```