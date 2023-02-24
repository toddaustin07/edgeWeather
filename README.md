# edgeWeather
## Overview
This SmartThings Edge driver creates a SmartThings device that provides weather data from select weather data sources:
* US Government
* OpenWeather
* WeatherUnderground
* WeatherFLow Tempest
* FMI

This driver requires no SmartApp, however it does require either my **Edge Bridge Server** or a standard **Proxy server**[^1] running on a computer on your network.  This provides the linkage for the Edge driver to reach internet endpoints which otherwise are not available to Edge drivers.  

[^1]: Due to a restriction in the current Edge platform implementation, reaching **HTTPS**-based addresses from Edge drivers is not supported using a standard proxy server.  Therefore, if the weather data source is only available via https and not http, then my Edge Bridge Server *must* be used.

The [Edge Bridge Server](https://github.com/toddaustin07/edgebridge) is a simple program you can download and run on any Windows, Linux, or Mac computer.  It requires no complicated setup. Just run it on an always-on computer with internet access and that's it.  An additional benefit to having this running on your network is that it enables expanded options for Edge drivers (like this one!), as well as easy integration with local apps and devices.  See the [Github readme](https://github.com/toddaustin07/edgebridge/blob/main/README.md)  for more details.


### Weather data sources
Currently, the edgeWeather driver provides 5 options for weather data, however it has been designed to be able to easily add more sources.  Please request them in the SmartThings community or in the Issues tab here in Github.  Provide working URLs for current data and forecast that I can use to test; [email](mailto:rpi.smartthings@gmail.com) them to me if they contain personal account data.

## Driver Pre-requisites
* SmartThings hub that supports Edge
* SmartThings ID
* Weather source account, if applicable
* An always-on computer on your local network with internet access
* Edge Bridge Server or standard Proxy server[^1]

  Download and run the Edge Bridge Server that meets your needs:

    * [Windows computer](https://github.com/toddaustin07/edgebridge/blob/main/edgebridge.exe)
      
      Open a command prompt window, navigate to the folder you downloaded the file to, and type 'edgebridge' and press enter.

    * [Linux or Mac (Python 3.x required)](https://github.com/toddaustin07/edgebridge/blob/main/edgebridge.py)
      
      Open a terminal window, navigate to the directory you downloaded the file to, and type 'python3 edgebridge.py' and press enter.

    * [Raspberry Pi](https://github.com/toddaustin07/edgebridge/blob/main/edgebridge4pi)
      
      Open a terminal window, navigate to the directory you downloaded the file to, and type 'chmod +x edgebridge4pi' and press enter (this makes the downloaded file executable).  Then to run it, type  './edgebridge4pi' and press enter.

  Alternatively, install a standard Proxy server such as [Privoxy](https://www.howtogeek.com/683971/how-to-use-a-raspberry-pi-as-a-proxy-server-with-privoxy/).
  
## Features

* Select weather data source
* Separate weather data URLs for current weather conditions and forecast
* Automatically refresh on a given interval
* Choice of displayed units for temperature, pressure, precip rate, windspeed and direction
### Data Elements
Availability of each depends on weather data source.

All data elements are available to automation routines, with the exception of Summary.
#### Current Conditions
* Temperature
* Humidity
* Low, High Temp
* Dew Point
* Precipitation Rate
* Probability of Precipitation
* Atmospheric Pressure (Barometer)
* Cloud cover (percentage)
* Illuminance
* UV Index
* Wind speed
* Wind Direction (degrees and abbreviations)
* Wind gust
* Summary
#### Forecast
* Temperature
* Humidity
* Low, High Temp
* Precipitation Rate
* Probability of Precipitation
* Cloud cover
* Wind speed
* Wind gust
* Summary
## Installation & Configuration
The driver is currently available on my [test channel](https://bestow-regional.api.smartthings.com/invite/Q1jP7BqnNNlL).  Enroll your hub and select **Edge Weather V1** from the list of drivers available to install.
When the driver is available on your hub, initiate an *Add device / Scan for nearby devices* from the SmartThings mobile app.  A new device will be created and found in your *No room assigned* or hub device room.  Open the device to the device *Settings* screen (three vertical dot menu in upper right of Controls screen).

### Settings
#### Weather Source
Choose OpenWeather, US Gov, WeatherFlow Tempest, FMI, or WeatherUnderground
#### Current Weather URL
The complete URL to retrieve the current weather conditions.

* Must be in the form: http(s)://<...>
* Must include any required account tokens or parameters
##### Examples
* https://api.openweathermap.org/data/2.5/weather?lat=nn.nnnn&lon=-nn.nnn&appid=xxxxxxxxxxxxxxxxxxxx
* https://opendata.fmi.fi/wfs?service=WFS&version=2.0.0&request=getFeature&storedquery_id=fmi::observations::weather::timevaluepair&place=helsinki
* http://api.weather.gov/stations/KBAZ/observations/latest
* https://api.weather.com/v2/pws/observations/current?stationId=XXXXXXX&format=json&units=e&apiKey=xxxxxxxxxxxxxxxxxxxxxxxxxx
* https://swd.weatherflow.com/swd/rest/observations/?device_id=xxxxxx&token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
* https://api.darksky.net/forecast/<usertoken\>/<latitude\>,<longitude\>?units=si&exclude=minutely,hourly
#### Weather Forecast URL
The complete URL to retrieve the weather forecast.  If the forecast data is contained in the *Current Weather URL*, then this can be left to 'xxxxx'.

* If provided, must be in the form: http(s)://<...>
* Must include any required account tokens or parameters
##### Examples
* http://api.weather.gov/gridpoints/EWX/142,70/forecast
* https://api.openweathermap.org/data/2.5/forecast?lat=nn.nnnn&lon=-nn.nnn&appid=xxxxxxxxxxxxxxxxxxxx
* https://opendata.fmi.fi/wfs?service=WFS&version=2.0.0&request=getFeature&storedquery_id=fmi::forecast::hirlam::surface::point::timevaluepair&place=helsinki
* https://api.weather.com/v3/wx/forecast/daily/5day?postalKey=nnnnn:US&format=json&units=e&language=en-US&apiKey=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
* https://swd.weatherflow.com/swd/rest/better_forecast/?station_id=xxxxx&device_id=xxxxxx&token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

#### Proxy Server Address
LAN address of either a standard Proxy server or the Edge Bridge Server[^1].
* Must be in the form: http://<IP address\>:<port number\>
* HTTPS is not currently supported
##### Example
* http://192.168.1.150:8088

#### Proxy Type
Choose either 'Standard Proxy Server'[^1] or 'Edge Bridge Server'

#### Periodic Refresh
Use this setting to enable or disable automatic refresh feature

#### Refresh Rate
Provide the number of minutes between refreshes (5-1,440)

#### Received Temperature Units
Set this value to the temperature units that is received from the weather data source (Celsius or Fahrenheit)

#### Displayed Temperature Units
Set this value to the temperature units that you use in your location (Celsius or Fahrenheit)

#### Received Pressure Units
Set this value to the barometric units that is received from the weather data source (Pascals, Kilopascal, inches of mercury, millibars)

#### Displayed Pressure Units
Set this value to the barometric units that you use in your location (Pascals, Kilopascal, inches of mercury, millibars)

#### Received Precip Rate Units
Set this value to the wind speed units that is received from the weather data source (m/hr, in/hr, mm/hr)

#### Displayed Precip Rate Units
Set this value to the wind speed units that you want to use for your location (m/hr, in/hr, mm/hr)

#### Received Wind Speed Units
Set this value to the wind speed units that is received from the weather data source (m/sec, knots, km/hr, mph)

#### Displayed Wind Speed Units
Set this value to the wind speed units that you want to use for your location (m/sec, knots, km/hr, mph)

#### Wind Direction Abbreviations
Set this value to control the display of wind directions between 8 directions (N, NE, E, etc.)  and 16 directions (N, NNE, NE, ENE, E, etc.)

### Usage
#### Controls screen

Values can be refreshed at any time by using the 'swipe-down' gesture.

After making any Settings changes, be sure to do a swipe-down gesture on the Controls screen to refresh the values.

Any fields that are blank or have 0 value may be due to no data available for that element from the weather source.

If forecast data is only available as hourly, then forecast data shown is typically for around noon-2pm the next day.

Use the Periodic Refresh option in device Settings to automatically update.

#### Routines
All data elements except Summary are available to include in an **IF** portion of an automation routine.

There are no **THEN** actions you can perform on the weather device.
