# ExtractTransformInflux
This script allows to extract data stored in an Influx time series measurement into a CSV file. There is an option to replace existing tag values with new values [#3904](https://github.com/influxdata/influxdb/issues/3904). The resulting CSV file can be exported back to another Influx Measurement or updaloded to same one, and old series can be dropped.

### Usage
```powershell
.\ExtractTransformInflux.ps1 -influxBaseUrl "http://localhost:8086/query?db=TestDB" -measurement "MyMeasurement"  -oldTags "AppName=App1;Release=Beta" -newTags "AppName=MyApplication;Release=Pre_Beta"
```
