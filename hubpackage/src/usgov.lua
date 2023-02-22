--[[
  Copyright 2022 Todd Austin

  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
  except in compliance with the License. You may obtain a copy of the License at:

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software distributed under the
  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
  either express or implied. See the License for the specific language governing permissions
  and limitations under the License.


  DESCRIPTION
  
  SmartThings Edge Weather Driver - parse US Gov data

--]]

local capabilities = require "st.capabilities"
local json = require "dkjson"
local log = require "log"


local function modify_current_url(current_url)

  return current_url

end


local function getnumvalue(value, valtype)

  if value then
    if type(value) == 'number' then; return value; end
  end
  
  if valtype == 'temp' then
    return -999
  else
    return 0
  end

end


local function update_current(device, weatherdata)

  local weathertable = {}
  weathertable.current = {}

  local data, pos, err = json.decode (weatherdata, 1, nil)


  weathertable.current.summary = {value=' '}
  
  weathertable.current.temperature = {value=getnumvalue(data.properties.temperature.value, 'temp')}
  
  weathertable.current.mintemp = {value=getnumvalue(data.properties.minTemperatureLast24Hours.value, 'temp')}
  weathertable.current.maxtemp = {value=getnumvalue(data.properties.maxTemperatureLast24Hours.value, 'temp')}
  
  weathertable.current.humidity = {value=getnumvalue(data.properties.relativeHumidity.value)}
  
  weathertable.current.precipprob = {value=0}
  
  weathertable.current.preciprate = {value=getnumvalue(data.properties.precipitationLastHour.value)}
  
  weathertable.current.pressure = {value=getnumvalue(data.properties.barometricPressure.value)}
  
  weathertable.current.cloudcover = {value=0}
  
  weathertable.current.dewpoint = {value=getnumvalue(data.properties.dewpoint.value), 'temp'}
  
  weathertable.current.windspeed = {value=getnumvalue(data.properties.windSpeed.value)}
  
  weathertable.current.winddegrees = {value=getnumvalue(data.properties.windDirection.value)}
  
  weathertable.current.windgust = {value=getnumvalue(data.properties.windGust.value)}
  
  return weathertable
  
end

local function update_forecast(device, weatherdata)

  local weathertable = {}
  weathertable.forecast = {}

  local data, pos, err = json.decode (weatherdata, 1, nil)

  -- determine which period is tomorrow
  
  local weekday = { ['monday'] = true, ['tuesday'] = true, ['wednesday'] = true, ['thursday'] = true, ['friday'] = true, 
                    ['saturday'] = true, ['sunday'] = true
                  }
                  
  for _, forecast in ipairs (data.properties.periods) do
    log.debug (forecast.name)
    if weekday[string.lower(forecast.name)] then
      
      weathertable.forecast.summary = {value=forecast.shortForecast}
      weathertable.forecast.temperature = {value=getnumvalue(forecast.temperature, 'temp'), unit=forecast.temperatureUnit}

      local windspeedtext = forecast.windSpeed
      local wmin, wmax = windspeedtext:match('(%d+) to (%d+) mph')
      wmin = tonumber(wmin)
      wmax = tonumber(wmax)
      local windspeed
      if wmin and wmax then
        windspeed = (wmin + wmax) / 2
      else
        windspeed = 0
      end      
      weathertable.forecast.windspeed = {value=windspeed}

      -- these values are not included in the received forecast data
      weathertable.forecast.mintemp = {value=-999}
      weathertable.forecast.maxtemp = {value=-999}
      weathertable.forecast.humidity = {value=0}
      weathertable.forecast.cloudcover = {value=0}
      weathertable.forecast.precipprob = {value=0}
      weathertable.forecast.preciprate = {value=0}
      weathertable.forecast.windgust = {value=0}
      
      
      return weathertable
    end
  end
end

return {
  modify_current_url = modify_current_url,
  update_current = update_current,
  update_forecast = update_forecast,
}
