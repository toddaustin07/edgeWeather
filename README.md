# edgeWeather
## Overview
This SmartThings Edge driver provides weather data from select weather data sources (currently US Government & Dark Sky).  It requires no SmartApp, however it does require either my Edge Bridge Server or a Proxy Server* running on a computer on your network.  This provides the linkage for the Edge driver to reach internet endpoints which otherwise are not available to Edge drivers.  

Currently the driver provides 2 options for weather data, however it has been designed to be able to easily add more sources.  Please request them in the SmartThings community or in the Issues tab here in Github.  Provide working URLs for current data and forecast that I can use to test.

\* Due to a current restriction in the Edge platform implementation, reaching **https**-based addresses is not supported using a standard proxy server.  If the weather data source is only available via https and not http, then my Edge Bridge Server must be used.

The [Edge Bridge Server](https://github.com/toddaustin07/edgebridge) is a simple program you can download and run on any Windows, Linux, or Mac computer.  It requires no complicated setup. Just run it on an always-on computer with internet access and that's it.

## Pre-requisites
* SmartThings hub that supports Edge
* SmartThings ID
* Edge Bridge Server or standard Proxy server (see caveat above)
* A computer on your local network to run the Edge Bridge Server or Proxy server
* Existing Dark Sky account if that is what you want to use (no new accounts can be created as it is being sunset); US Government weather does not require an account

## Features

* Select weather data source
* Separate weather data URLs for current weather conditions and forecast
* Automatically refresh on a given interval
* Choice of displayed wind speed units: m/sec, knots, km/h, mph
### Data Elements
Availability of each depends on weather data source.

All data elements are available to automation routines, with the exception of Summary.
#### Current Conditions
* Temperature
* Humidity
* Dew Point
* Precipitation Intensity
* Probability of Precipitation
* Atmospheric Pressure (Barometer)
* UV Index
* Cloud cover (percentage)
* Wind speed
* Wind bearing
* Summary
#### Forecast
* Probability of Precipitation
* Summary
## Installation & Configuration
The driver is currently available on my [test channel](https://bestow-regional.api.smartthings.com/invite/Q1jP7BqnNNlL).  Enroll your hub and select edgeWeather from the list of drivers available to install.
When the driver is available on your hub, initiate an *Add device / Scan for nearby devices* from the SmartThings mobile app.  A new device will be created and found in your *No room assigned* room.  Open the device to the device *Settings* screen (three vertical dot menu in upper right of Controls screen).

### Settings
#### Weather Source
Choose US Gov or Dark Sky
#### Current Weather URL
The complete URL to retrieve the current weather conditions.

* Must be in the form: http(s)://<...>
* Must include any account tokens or desired parameters
##### Examples
* http://api.weather.gov/stations/KBAZ/observations/latest
* https://api.darksky.net/forecast/\<usertoken\>/<latitude>,<longitude>?units=si&exclude=minutely,hourly
#### Weather Forecast URL
The complete URL to retrieve the weather forecast.  If the forecast data is contained in the *Current Weather URL*, then this can be left to 'xxxxx'.

* Must be in the form: http(s)://<...>
* Must include any account tokens or desired parameters
##### Examples
* http://api.weather.gov/gridpoints/EWX/142,70/forecast
* leave as 'xxxxx' for Dark Sky

#### Proxy Server Address
LAN address of either a standard Proxy server or the Edge Bridge Server.
* Must be in the form: http://<IP address>:<port number>
* HTTPS is not currently supported
##### Example
* http://192.168.1.150:8088

#### Proxy Type
Choose either 'Standard Proxy Server' or 'Edge Bridge Server'

#### Periodic Refresh
Use this setting to enable or disable automatic refresh feature

#### Refresh Rate
Provide the number of minutes between refreshes (5-1,440)

#### Received Temperature Units
Set this value to the temperature units that is received from the weather data source (Celsius or Fahrenheit)

#### Displayed Temperature Units
Set this value to the temperature units that you use in your location (Celsius or Fahrenheit)

#### Received Wind Speed Units
Set this value to the wind speed units that is received from the weather data source (m/sec, knots, km/hr, mph)

#### Displayed Wind Speed Units
Set this value to the wind speed units that you want to use for your location (m/sec, knots, km/hr, mph)
