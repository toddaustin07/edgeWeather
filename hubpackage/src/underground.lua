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
  
  SmartThings Edge Weather Driver - parse Weather Underground data

--]]

local capabilities = require "st.capabilities"
local json = require "dkjson"
local log = require "log"

local util = require "common"

local MINMAXTEMPFC_NEXTDAYINDEX = 2


local function modify_current_url(current_url)

  return current_url

end


local function getnumvalue(data, keystr)

  local elementlist = {}
  local check = data

  for str in string.gmatch(keystr, "([^.]+)") do
    check = check[str]
    if not check then
      if keystr == 'temp' or keystr == 'dewpt' then
        return -999
      else
        return 0
      end
    end
  end
  
  return check

end


local function set0ifna(item, index, valtype)

  if item then
    if item[index] then
      return item[index]
    end
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
  
  local root
  if data.observations[1].imperial then
    root = data.observations[1].imperial
  elseif data.observations[1].metric then
    root = data.observations[1].metric
  else
    return 
  end
  
  weathertable.current.temperature = {value=getnumvalue(root, 'temp')}
  
  weathertable.current.dewpoint = {value=getnumvalue(root, 'dewpt')}
  
  weathertable.current.pressure = {value=getnumvalue(root, 'pressure')}
  
  weathertable.current.lux = {value=getnumvalue(data.observations[1], 'solarRadiation')}
  
  weathertable.current.uv = {value=getnumvalue(data.observations[1], 'uv')}
  
  weathertable.current.humidity = {value=getnumvalue(data.observations[1], 'humidity')}
  
  weathertable.current.windspeed = {value=getnumvalue(root, 'windSpeed')}
  
  weathertable.current.windgust = {value=getnumvalue(root, 'windGust')}
  
  weathertable.current.winddegrees = {value=getnumvalue(data.observations[1], 'winddir')}
  
  weathertable.current.preciprate = {value=getnumvalue(root, 'precipRate')}
   
  -- Unavailable fields
  
  weathertable.current.summary = {value=' '}
  
  weathertable.current.cloudcover = {value=0}
  
  weathertable.current.precipprob = {value=0}
  
  weathertable.current.mintemp = {value=-999}
  weathertable.current.maxtemp = {value=-999}
  
  
  return weathertable
  
end


local function update_forecast(device, weatherdata)

  local weathertable = {}
  weathertable.forecast = {}

  local data, pos, err = json.decode (weatherdata, 1, nil)

  -- determine which forecast period is tomorrow
  
  if data.daypart[1] then
    local fc = data.daypart[1]
    local daypart_index
    for i=1, #fc.daypartName do
      if fc.daypartName[i] == 'Tomorrow' then; daypart_index = i; end
    end
    
    if daypart_index then
    
      log.debug (string.format('Using daypart forecast index #%s', daypart_index))
      
      weathertable.forecast.temperature = {value=set0ifna(fc.temperature, daypart_index, 'temp')}

      
      weathertable.forecast.humidity = {value=set0ifna(fc.relativeHumidity, daypart_index)}
      weathertable.forecast.precipprob = {value=set0ifna(fc.precipChance, daypart_index)}
      weathertable.forecast.cloudcover = {value=set0ifna(fc.cloudCover, daypart_index)}
      weathertable.forecast.windspeed = {value=set0ifna(fc.windSpeed, daypart_index)}
      
      weathertable.forecast.summary = {value=' '}
      if fc.wxPhraseLong then
        if fc.wxPhraseLong[daypart_index] then
          weathertable.forecast.summary = {value=fc.wxPhraseLong[daypart_index]}
        end
      end
      
      log.debug('Curent Hub day (UTC):', os.date('%A'))
      log.debug('FC data- validTimeLocal[1]:', data.validTimeLocal[1])

      -- Determine the local time offset
      local offset_sign, offset_hrs, offset_mins = data.validTimeLocal[1]:match('[%d%-]+T[%d%:]+([%+%-])(%d%d)(%d%d)$')
      local offset_multiplier = tonumber(offset_sign .. '1')
      local localtime_offset = (tonumber(offset_hrs) * 3600 + tonumber(offset_mins) * 60) * offset_multiplier
      log.debug (string.format('Local time offset in seconds=%d', localtime_offset))
      local tomorrow = os.date('%A', os.time() + localtime_offset + 86400)
      log.debug ('Computed Tomorrow:', tomorrow)
      
      if data.dayOfWeek then
        for i=1, #data.dayOfWeek do
          if data.dayOfWeek[i] == tomorrow then
            log.debug (string.format('Using d-o-w forecast index #%d for min/max temp', i))
            weathertable.forecast.mintemp = {value=set0ifna(data.temperatureMin, i, 'temp')}
            weathertable.forecast.maxtemp = {value=set0ifna(data.temperatureMax, i, 'temp')}
            break
          end
        end
      end
      
      -- Unavailable
      weathertable.forecast.preciprate = {value=0}
      weathertable.forecast.windgust = {value=0}
        
        
      return weathertable
        
    else
      log.error ('Tomorow forecast not found')
    end
  else
    log.error ('Forecast data not found')
  end
end

return {
  modify_current_url = modify_current_url,
  update_current = update_current,
  update_forecast = update_forecast,
}
