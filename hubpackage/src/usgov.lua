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
local stutils = require "st.utils"
local common = require "common"
local log = require "log"

local function update_current(device, data)

  device:emit_component_event(device.profile.components.main, cap_summary.summary(' ', { visibility = { displayed = false } }))
  
  local temp = data.properties.temperature.value
  local unit = 'C'
  
  if device.preferences.rtempunit == 'fahrenheit' then
    unit = 'F'
  end
  device:emit_component_event(device.profile.components.main, capabilities.temperatureMeasurement.temperature({value = temp, unit=unit}))
  
  device:emit_component_event(device.profile.components.main, capabilities.relativeHumidityMeasurement.humidity(data.properties.relativeHumidity.value))
  
  device:emit_component_event(device.profile.components.main, cap_precipprob.probability(0))
  
  local recentprecip = data.properties.precipitationLastHour.value
  log.debug ('Recent precip', recentprecip)
  if type(recentprecip) ~= 'number' then
    recentprecip = 0
  end
  device:emit_component_event(device.profile.components.main, cap_precip.precip({value=recentprecip, unit='mm/hr'}))

  local precip
  if recentprecip == 0 then
    precip = 'none'
  elseif recentprecip > 0 and recentprecip < 2 then
    precip = 'light'
  
  elseif recentprecip >= 2 and recentprecip <= 10 then
    precip = 'moderate'
  
  elseif recentprecip > 10 and recentprecip < 50 then
    precip = 'heavy'
    
  elseif recentprecip >= 50 then
    precip = 'violent'
  end
  device:emit_component_event(device.profile.components.main, capabilities.precipitationSensor.precipitationIntensity(precip))
  
  device:emit_component_event(device.profile.components.main, capabilities.atmosphericPressureMeasurement.atmosphericPressure(data.properties.barometricPressure.value/1000))
  device:emit_component_event(device.profile.components.main, cap_barometer.pressure({value=data.properties.barometricPressure.value/100, unit='mB'}))
  
  device:emit_component_event(device.profile.components.main, capabilities.ultravioletIndex.ultravioletIndex(0))
  device:emit_component_event(device.profile.components.main, cap_cloudcover.cloudcover({value=0, unit='%'}))
  
  local dewpoint = data.properties.dewpoint.value
  if device.preferences.rtempunit == 'celsius' and device.preferences.dtempunit == 'fahrenheit' then
    dewpoint = math.floor(stutils.c_to_f(dewpoint))
  elseif device.preferences.rtempunit == 'fahrenheit' and device.preferences.dtempunit == 'celsius' then
    dewpoint = math.floor(stutils.f_to_c(dewpoint))
  end
  device:emit_component_event(device.profile.components.main, cap_dewpoint.dewpoint(dewpoint))
  
  local windspeed = data.properties.windSpeed.value
  if type(windspeed) ~= 'number' then
    windspeed = 0
  end
  local windval, windunit = common.convert_wind(windspeed, device.preferences.rwindunit, device.preferences.dwindunit)
  log.debug ('windval:', windval)
  device:emit_component_event(device.profile.components.main, cap_windspeed.wSpeed({value=windval, unit=windunit}))

  local winddir = data.properties.windDirection.value
  if type(winddir) ~= 'number' then
    winddir = 0
  end
  device:emit_component_event(device.profile.components.main, cap_windbearing.windbearing(winddir))
  
end

local function update_forecast(device, data)

  -- determine which period is tomorrow
  
  local weekday = { ['monday'] = true, ['tuesday'] = true, ['wednesday'] = true, ['thursday'] = true, ['friday'] = true, 
                    ['saturday'] = true, ['sunday'] = true
                  }
                  
  for _, forecast in ipairs (data.properties.periods) do
    log.debug (forecast.name)
    if weekday[string.lower(forecast.name)] then
      device:emit_component_event(device.profile.components.tomorrow, cap_summary.summary(forecast.shortForecast))
      device:emit_component_event(device.profile.components.tomorrow, cap_precipprob.probability(0))
      break
    end
  end
end

return {
  update_current = update_current,
  update_forecast = update_forecast,
}
