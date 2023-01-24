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
  
  SmartThings Edge Weather Driver - parse OpenWeather data

--]]

local capabilities = require "st.capabilities"
local json = require "dkjson"
local log = require "log"


local function modify_current_url(current_url)

  return current_url

end


local function getnumvalue(data, keystr)

  local elementlist = {}
  local check = data

  for str in string.gmatch(keystr, "([^.]+)") do
    check = check[str]
    if not check then
      return 0
    end
  end
  
  return check

end


local function update_current(device, weatherdata)

  local weathertable = {}
  weathertable.current = {}

  local data, pos, err = json.decode (weatherdata, 1, nil)

  local summary = ' '
  if data.weather[1] then
    if data.weather[1].description then
      summary = data.weather[1].description
    end
  end
  weathertable.current.summary = {value=summary}
  
  weathertable.current.temperature = {value=getnumvalue(data, 'main.temp')-273.15}
  
  weathertable.current.mintemp = {value=getnumvalue(data, 'main.temp_min')-273.15}
  weathertable.current.maxtemp = {value=getnumvalue(data, 'main.temp_max')-273.15}
  
  weathertable.current.pressure = {value=getnumvalue(data, 'main.pressure')}
  
  weathertable.current.humidity = {value=getnumvalue(data, 'main.humidity')}
  
  weathertable.current.windspeed = {value=getnumvalue(data, 'wind.speed')}
  
  weathertable.current.windgust = {value=getnumvalue(data, 'wind.gust')}
  
  weathertable.current.winddegrees = {value=getnumvalue(data, 'wind.deg')}
  
  weathertable.current.cloudcover = {value=getnumvalue(data, 'clouds.all')}
  
  weathertable.current.preciprate = {value=getnumvalue(data, 'rain.1h')}
   
  -- Unavailable fields
  weathertable.current.precipprob = {value=0}
  
  weathertable.current.uv = {value=0}
  
  weathertable.current.dewpoint = {value=-999}
  
  return weathertable
  
end

local function update_forecast(device, weatherdata)

  local weathertable = {}
  weathertable.forecast = {}

  local data, pos, err = json.decode (weatherdata, 1, nil)

  -- determine which forecast period is tomorrow noonish
  
  if data.list and #data.list > 0 then
  
    local index, foundindex
    local current_day, current_hour
    local current_dt = os.date('*t', os.time()+data.city.timezone)
    
    current_day = current_dt.day
    current_hour = current_dt.hour
    log.debug ('Current day, hour=', current_day, current_hour)
    if current_hour < 3 then; current_day = 0; end    -- If prior to 3am, use fc for later this same day
    
    local next_utc, next_dt
    local next_day, next_hour
    
    for index=1, #data.list do
      next_utc = data.list[index].dt
      next_dt = os.date('*t', next_utc+data.city.timezone)
      next_day = next_dt.day
      next_hour = next_dt.hour
      
      if next_day ~= current_day and next_hour > 11 then
        foundindex=index
        break;
      end
    end

    if foundindex then
      log.debug (string.format('Using forecast #%s', foundindex))
      log.debug (string.format('\t%s/%s/%s  %s:%s', next_dt.month,next_dt.day,next_dt.year,next_dt.hour,next_dt.min))
      
      local fc = data.list[foundindex]
  
      weathertable.forecast.temperature = {value=getnumvalue(fc, 'main.temp')-273.15}
      
      weathertable.forecast.mintemp = {value=getnumvalue(fc, 'main.temp_min')-273.15}
      weathertable.forecast.maxtemp = {value=getnumvalue(fc, 'main.temp_max')-273.15}
      
      weathertable.forecast.humidity = {value=getnumvalue(fc, 'main.humidity')}
      
      weathertable.forecast.precipprob = {value=getnumvalue(fc, 'pop')*100}
      weathertable.forecast.preciprate = {value=getnumvalue(fc, 'rain.3h')}
      
      weathertable.forecast.cloudcover = {value=getnumvalue(fc, 'clouds.all')}
      
      weathertable.forecast.windspeed = {value=getnumvalue(fc, 'wind.speed')}
      
      weathertable.forecast.windgust = {value=getnumvalue(fc, 'wind.gust')}
      
      local summary = ' '
      if fc.weather[1] then
        if fc.weather[1].description then
          summary = fc.weather[1].description
        end
      end
      weathertable.forecast.summary = {value=summary}
      
      return weathertable
      
    else
      log.error ('Next day forecast not found')
    end
    
  else
    log.warn ('No forecast list found in response data')
  end
  
end

return {
  modify_current_url = modify_current_url,
  update_current = update_current,
  update_forecast = update_forecast,
}
