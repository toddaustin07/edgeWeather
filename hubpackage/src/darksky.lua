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
  
  SmartThings Edge Weather Driver - parse Dark sky data

--]]

local capabilities = require "st.capabilities"
local json = require "dkjson"
local log = require "log"


local function modify_current_url(current_url)

  return current_url

end


local function update_current(device, weatherdata)

  local weathertable = {}
  weathertable.current = {}

  local data, pos, err = json.decode (weatherdata, 1, nil)

  weathertable.current.summary = {value=data.currently.summary}
  weathertable.current.temperature = {value=data.currently.temperature}
  weathertable.current.humidity = {value=data.currently.humidity * 100}
  weathertable.current.preciprate = {value=data.currently.precipIntensity}
  weathertable.current.precipprob = {value=data.currently.precipProbability*100}
  weathertable.current.pressure = {value=data.currently.pressure}
  weathertable.current.uv = {value=data.currently.uvIndex}
  weathertable.current.cloudcover = {value=data.currently.cloudCover*100}
  weathertable.current.dewpoint = {value=data.currently.dewPoint}
  weathertable.current.windspeed = {value=data.currently.windSpeed}
  
  local winddir = data.currently.windBearing
  if type(winddir) ~= 'number' then; winddir = 0; end
  weathertable.current.winddegrees = {value=winddir}
  
  weathertable.current.mintemp = {value=-999}
  weathertable.current.maxtemp = {value=-999}
  weathertable.current.windgust = {value=0}
  
  return weathertable
  
end

local function update_forecast(device, weatherdata)

  local weathertable = {}
  weathertable.forecast = {}
  
  local data, pos, err = json.decode (weatherdata, 1, nil)

  local dailylist = data.daily.data
  
  local curdayofweek = os.date('%c', data.currently.time):match('(%a+) ')
  log.debug ('current weekday: ', curdayofweek)
  
  local nextweekday = {
                        ['Mon'] = 'Tue',
                        ['Tue'] = 'Wed',
                        ['Wed'] = 'Thu',
                        ['Thu'] = 'Fri',
                        ['Fri'] = 'Sat',
                        ['Sat'] = 'Sun',
                        ['Sun'] = 'Mon'
                      }
  
  for _, item in ipairs(dailylist) do
    log.debug ('found weekday: ', os.date('%c', item.time):match('(%a+) '))
    
    if os.date('%c', item.time):match('(%a+) ') == nextweekday[curdayofweek] then

      weathertable.forecast.summary = {value=item.summary}
      weathertable.forecast.temperature = {value=(tonumber(item.temperatureHigh) + tonumber(item.temperatureLow) / 2)}
      weathertable.forecast.humidity = {value=item.humidity * 100}
      weathertable.forecast.preciprate = {value=item.precipIntensity}
      weathertable.forecast.precipprob = {value=item.precipProbability*100}
      weathertable.forecast.cloudcover = {value=item.cloudCover*100}
      weathertable.forecast.windspeed = {value=item.windSpeed}
      
      weathertable.forecast.mintemp = {value=-999}
      weathertable.forecast.maxtemp = {value=-999}
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
