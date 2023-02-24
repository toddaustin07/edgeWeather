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
  
  SmartThings Edge Weather Driver - parse WeatherFlow Tempest data

--]]

local capabilities = require "st.capabilities"
local json = require "dkjson"
local log = require "log"

local emitter = require "emitter"

local function modify_current_url(current_url)

  return current_url

end


--[[
obs[1][n] :   (index+1 for Lua tables)
0 - Epoch (Seconds UTC)
1 - Wind Lull (m/s)
2 - Wind Avg (m/s)
3 - Wind Gust (m/s)
4 - Wind Direction (degrees)
5 - Wind Sample Interval (seconds)
6 - Pressure (MB)
7 - Air Temperature (C)
8 - Relative Humidity (%)
9 - Illuminance (lux)
10 - UV (index)
11 - Solar Radiation (W/m^2)
12 - Rain Accumulation (mm)
13 - Precipitation Type (0 = none, 1 = rain, 2 = hail, 3 = rain + hail (experimental))
14 - Average Strike Distance (km)
15 - Strike Count
16 - Battery (volts)
17 - Report Interval (minutes)
18 - Local Day Rain Accumulation (mm)
19 - NC Rain Accumulation (mm)
20 - Local Day NC Rain Accumulation (mm)
21 - Precipitation Aanalysis Type (0 = none, 1 = Rain Check with user display on, 2 = Rain Check with user display off)
--]]


local function update_current(device, weatherdata)

  local weathertable = {}
  weathertable.current = {}

  local data, pos, err = json.decode (weatherdata, 1, nil)

  weathertable.current.temperature = {value=data.obs[1][8]}
  
  weathertable.current.pressure = {value=data.obs[1][7]}
  
  weathertable.current.humidity = {value=data.obs[1][9]}
  
  weathertable.current.windspeed = {value=data.obs[1][3]}
  
  weathertable.current.windgust = {value=data.obs[1][4]}
  
  weathertable.current.winddegrees = {value=data.obs[1][5]}
  
  weathertable.current.lux = {value=data.obs[1][10]}
  
  weathertable.current.uv = {value=data.obs[1][11]}
  
   
  -- Unavailable fields
  weathertable.current.summary = {value=' '}      -- picked up in forecast data
  
  weathertable.current.mintemp = {value=-999}
  weathertable.current.maxtemp = {value=-999}
  
  weathertable.current.precipprob = {value=0}
  weathertable.current.preciprate = {value=0}
  
  weathertable.current.cloudcover = {value=0}
  weathertable.current.dewpoint = {value=-999}     -- picked up in forecast data
  
  return weathertable
  
end

local function update_forecast(device, weatherdata)

  local weathertable = {}
  weathertable.forecast = {}

  local data, pos, err = json.decode (weatherdata, 1, nil)

  -- Forecast contains current conditions summary & dewpoint, so display them
  
  emitter._emit_summary(device, device.profile.components.main, data.current_conditions.conditions)
  emitter._emit_dewpoint(device, device.profile.components.main, {value = data.current_conditions.dew_point})

  -- determine which forecast period is tomorrow
  
  if data.forecast.daily then
  
    local foundflag = false
    local dayforecast
    
    local currtime = os.time()
    local timezone_offset_seconds = data.timezone_offset_minutes * 60
    
    log.debug ('Hub time (GMT):', os.date('%m/%d %H:%M', currtime))
    log.debug (string.format('Timezone offset: %d minutes', data.timezone_offset_minutes))
    
    log.debug ('Local time:', os.date('%m/%d %H:%M', currtime+timezone_offset_seconds))
    
    local curr_daynum = os.date('*t', currtime+timezone_offset_seconds).day
    local next_daynum = os.date('*t', currtime+timezone_offset_seconds+86400).day
    
    log.debug ('Curent day =', curr_daynum)
    log.debug ('Next day =', next_daynum)
    
    for _, forecast in ipairs(data.forecast.daily) do
      if forecast.day_num == curr_daynum then
        emitter._emit_precipprob(device, device.profile.components.main, forecast.precip_probability)
        
      elseif forecast.day_num == next_daynum then
        foundflag = true 
        dayforecast = forecast
        break
      end
    end

    if foundflag == true then
      weathertable.forecast.summary = {value=dayforecast.conditions}
      weathertable.forecast.mintemp = {value=dayforecast.air_temp_low}
      weathertable.forecast.maxtemp = {value=dayforecast.air_temp_high}
      weathertable.forecast.precipprob = {value=dayforecast.precip_probability}
      
      weathertable.forecast.temperature = {value=-999}
      weathertable.forecast.humidity = {value=0}
      weathertable.forecast.preciprate = {value=0}
      weathertable.forecast.cloudcover = {value=0}
      weathertable.forecast.windspeed = {value=0}
      weathertable.forecast.windgust = {value=0}
    
      return weathertable
      
    else
      log.error ('Next day forecast not found')
    end
    
  else
    log.warn ('No daily forecast data found in response data')
  end
  
end

return {
  modify_current_url = modify_current_url,
  update_current = update_current,
  update_forecast = update_forecast,
}
