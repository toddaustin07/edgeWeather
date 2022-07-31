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
local stutils = require "st.utils"
local common = require "common"
local log = require "log"

local function update_current(device, data)

  device:emit_component_event(device.profile.components.main, cap_summary.summary(data.currently.summary))
  
  local temp = data.currently.temperature
  local unit = 'C'
  
  if device.preferences.rtempunit == 'fahrenheit' then
    unit = 'F'
  end
  device:emit_component_event(device.profile.components.main, capabilities.temperatureMeasurement.temperature({value = temp, unit=unit}))
  
  device:emit_component_event(device.profile.components.main, capabilities.relativeHumidityMeasurement.humidity(data.currently.humidity * 100))
  
  device:emit_component_event(device.profile.components.main, cap_precip.precip({value=data.currently.precipIntensity, unit='mm/hr'}))
  device:emit_component_event(device.profile.components.main, cap_precipprob.probability(data.currently.precipProbability))
  
  local precip
  if data.currently.precipIntensity == 0 then
    precip = 'none'
  elseif data.currently.precipIntensity > 0 and data.currently.precipIntensity < 2 then
    precip = 'light'
  
  elseif data.currently.precipIntensity >= 2 and data.currently.precipIntensity <= 10 then
    precip = 'moderate'
  
  elseif data.currently.precipIntensity > 10 and data.currently.precipIntensity < 50 then
    precip = 'heavy'
    
  elseif data.currently.precipIntensity >= 50 then
    precip = 'violent'
  end
  
  device:emit_component_event(device.profile.components.main, capabilities.precipitationSensor.precipitationIntensity(precip))
  
  device:emit_component_event(device.profile.components.main, capabilities.atmosphericPressureMeasurement.atmosphericPressure(data.currently.pressure/10))
  device:emit_component_event(device.profile.components.main, cap_barometer.pressure({value=data.currently.pressure, unit='mB'}))
  
  device:emit_component_event(device.profile.components.main, capabilities.ultravioletIndex.ultravioletIndex(data.currently.uvIndex))
  device:emit_component_event(device.profile.components.main, cap_cloudcover.cloudcover({value=data.currently.cloudCover*100, unit='%'}))
  
  local dewpoint = data.currently.dewPoint
  if device.preferences.rtempunit == 'celsius' and device.preferences.dtempunit == 'fahrenheit' then
    dewpoint = math.floor(stutils.c_to_f(dewpoint))
  elseif device.preferences.rtempunit == 'fahrenheit' and device.preferences.dtempunit == 'celsius' then
    dewpoint = math.floor(stutils.f_to_c(dewpoint))
  end
  device:emit_component_event(device.profile.components.main, cap_dewpoint.dewpoint(dewpoint))
  
  local windval, windunit = common.convert_wind(data.currently.windSpeed, device.preferences.rwindunit, device.preferences.dwindunit)
  log.debug ('windval:', windval)
  device:emit_component_event(device.profile.components.main, cap_windspeed.wSpeed({value=windval, unit=windunit}))

  device:emit_component_event(device.profile.components.main, cap_windbearing.windbearing(data.currently.windBearing))
  
end

local function update_forecast(device, data)

  device:emit_component_event(device.profile.components.tomorrow, cap_summary.summary(data.daily.data[1].summary))
  device:emit_component_event(device.profile.components.tomorrow, cap_precipprob.probability(data.daily.data[1].precipProbability))

end

return {
  update_current = update_current,
  update_forecast = update_forecast,
}
