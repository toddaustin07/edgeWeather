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
  
  SmartThings Edge Weather Driver - SmartThings updates; also handles any needed unit conversions

--]]

-- Edge libraries
local capabilities = require "st.capabilities"
local stutils = require "st.utils"
local log = require "log"

-- Driver modules
local common = require "common"

-- Custom capabilities
local cap_summary = capabilities["partyvoice23922.summary"]
local cap_precip = capabilities["partyvoice23922.preciprate"]
local cap_precipprob = capabilities["partyvoice23922.precipprob"]
local cap_barometer = capabilities["partyvoice23922.barometer2"]
local cap_cloudcover = capabilities["partyvoice23922.cloudcover"]
local cap_dewpoint = capabilities["partyvoice23922.dewpoint"]
local cap_windspeed = capabilities["partyvoice23922.windspeed5"]
local cap_winddirection = capabilities["partyvoice23922.winddirection2"]
local cap_windcompass = capabilities["partyvoice23922.winddirdeg"]
local cap_mintemp = capabilities["partyvoice23922.tempmin"]
local cap_maxtemp = capabilities["partyvoice23922.tempmax"]
local cap_windgust = capabilities["partyvoice23922.windgust"]


local function _emit_summary(device, component, value)

  local emit_options = nil
  
  if value == ' ' then
    emit_options = { visibility = { displayed = false } }
  end
  
  device:emit_component_event(component, cap_summary.summary(value, emit_options))

end


local function _check_na(device, val, unit)

  if val == -999 then
    val = 0
    if device.preferences.dtempunit == 'celsius' then
      unit = 'C'
    elseif device.preferences.dtempunit == 'fahrenheit' then
      unit = 'F'
    end
  end
  
  return val, unit

end


local function _emit_temp(device, component, tmptbl)

  local temp = tmptbl.value
  local unit = 'C'

  if tmptbl.unit then
    unit = tmptbl.unit
  else
    if device.preferences.rtempunit == 'fahrenheit' then; unit = 'F'; end
  end

  -- Override if temp not available
  temp, unit = _check_na(device, temp, unit)

  device:emit_component_event(component, capabilities.temperatureMeasurement.temperature({value=temp, unit=unit}))
  
end

local function _emit_minmaxtemp(device, component, tmptbl, minmax)

  local temp = tmptbl.value
  local unit = 'C'

  if device.preferences.dtempunit == 'fahrenheit' then; unit = 'F'; end

  if temp ~= -999 then
  
    if device.preferences.rtempunit == 'fahrenheit' then
      if device.preferences.dtempunit == 'celsius' then
        temp = (temp - 32) * .5556
      end
    elseif device.preferences.rtempunit == 'celsius' then
      if device.preferences.dtempunit == 'fahrenheit' then
        temp = (temp * 1.8) + 32
        unit = 'F'
      end
    end
    
    temp = math.floor(temp * 10) / 10
    
  else
    temp, unit = _check_na(device, temp, unit)
  end
  
  if minmax == 'min' then
    device:emit_component_event(component, cap_mintemp.mintemp({value = temp, unit=unit}))
  elseif minmax == 'max' then
    device:emit_component_event(component, cap_maxtemp.maxtemp({value = temp, unit=unit}))
  end

end

local function _emit_preciprate(device, component, value)

  local precipval, precipunit = common.convert_precip(value, device.preferences.rprecipunit, device.preferences.dprecipunit)
  device:emit_component_event(component, cap_precip.precip({value=precipval, unit=precipunit}))
  
  if precipunit ~= 'mm/hr' then
    precipval, _ = common.convert_precip(value, device.preferences.rprecipunit, 'mmhr')
  end
  local preciptxt
  if precipval == 0 then
    preciptxt = 'none'
  elseif precipval > 0 and precipval < 2 then
    preciptxt = 'light'
  
  elseif precipval >= 2 and precipval <= 10 then
    preciptxt = 'moderate'
  
  elseif precipval > 10 and precipval < 50 then
    preciptxt = 'heavy'
    
  elseif precipval >= 50 then
    preciptxt = 'violent'
  end
  device:emit_component_event(component, capabilities.precipitationSensor.precipitationIntensity(preciptxt))
  
end


local function _emit_precipprob(device, component, probvalue)

  device:emit_component_event(component, cap_precipprob.probability({value=probvalue, unit='%'}))

end


local function _emit_windspeed(device, component, value, which)

  local windval, windunit = common.convert_wind(value, device.preferences.rwindunit, device.preferences.dwindunit)
  log.debug ('windval:', windval)
  
  if which == 'gust' then
    device:emit_component_event(component, cap_windgust.windgust({value=windval, unit=windunit}))
  else
    device:emit_component_event(component, cap_windspeed.wSpeed({value=windval, unit=windunit}))
  end
end

local function _emit_dewpoint(device, component, dewpoint)

  local dewpointval
  local _dewpointval = dewpoint.value
  local unit = 'C'
  
  if dewpoint.unit then
    unit = dewpoint.unit
  else
    if device.preferences.rtempunit == 'fahrenheit' then; unit = 'F'; end
  end
  
  -- Override if dewpoint not available (-999)
  dewpointval, unit = _check_na(device, _dewpointval, unit)
  
  device:emit_component_event(component, capabilities.dewPoint.dewpoint({value=dewpointval, unit=unit}))

end


local function emit_current(device, data)

  if data == nil then; return; end

  -- Summary
  _emit_summary(device, device.profile.components.main, data.current.summary.value)
  
  -- Temperature
  _emit_temp(device, device.profile.components.main, data.current.temperature)
  
  -- Humidity
  device:emit_component_event(device.profile.components.main, capabilities.relativeHumidityMeasurement.humidity(data.current.humidity.value))
  
  -- Min Temp
  _emit_minmaxtemp(device, device.profile.components.main, data.current.mintemp, 'min')
  
  -- Max Temp
  _emit_minmaxtemp(device, device.profile.components.main, data.current.maxtemp, 'max')
  
  -- Precip rate
  _emit_preciprate(device, device.profile.components.main, data.current.preciprate.value)
  
  -- Precip probability
  _emit_precipprob(device, device.profile.components.main, data.current.precipprob.value)
  --device:emit_component_event(device.profile.components.main, cap_precipprob.probability({value=data.current.precipprob.value, unit='%'}))
  
  -- Pressure
  local pressval, pressunit = common.convert_pressure(data.current.pressure.value, device.preferences.rpressureunit, device.preferences.dpressureunit)
  device:emit_component_event(device.profile.components.main, cap_barometer.pressure({value=pressval, unit=pressunit}))
  
  if pressunit ~= 'kPa' then
    pressval, _ = common.convert_pressure(data.current.pressure.value, device.preferences.rpressureunit, 'kpa')
  end
  device:emit_component_event(device.profile.components.main, capabilities.atmosphericPressureMeasurement.atmosphericPressure(pressval))
  
  -- Cloud cover
  device:emit_component_event(device.profile.components.main, cap_cloudcover.cloudcover({value=data.current.cloudcover.value, unit='%'}))
  
  -- Illuminance
  if device:supports_capability_by_id('illuminanceMeasurement') and data.current.lux then
    device:emit_component_event(device.profile.components.main, capabilities.illuminanceMeasurement.illuminance(data.current.lux.value))
  end
  
  -- UV Index
  if device:supports_capability_by_id('ultravioletIndex') and data.current.uv then
    device:emit_component_event(device.profile.components.main, capabilities.ultravioletIndex.ultravioletIndex(data.current.uv.value))
  end
  
  -- Dewpoint
  _emit_dewpoint(device, device.profile.components.main, data.current.dewpoint)
  
  -- Wind speed
  _emit_windspeed(device, device.profile.components.main, data.current.windspeed.value)
  
  -- Wind direction
  
    device:emit_component_event(device.profile.components.main, cap_windcompass.winddeg(data.current.winddegrees.value))
    device:emit_component_event(device.profile.components.main, cap_winddirection.direction(common.get_winddir(device, data.current.winddegrees.value)))
  
  -- Wind gust
  _emit_windspeed(device, device.profile.components.main, data.current.windgust.value, 'gust')
  
end

local function emit_forecast(device, data)
  
  if data == nil then; return; end
  
  -- Summary
  _emit_summary(device, device.profile.components.tomorrow, data.forecast.summary.value)
  
  -- Temperature
  _emit_temp(device, device.profile.components.tomorrow, data.forecast.temperature)
  
  -- Humidity
  device:emit_component_event(device.profile.components.tomorrow, capabilities.relativeHumidityMeasurement.humidity(data.forecast.humidity.value))
  
  -- Min Temp
  _emit_minmaxtemp(device, device.profile.components.tomorrow, data.forecast.mintemp, 'min')
  
  -- Max Temp
  _emit_minmaxtemp(device, device.profile.components.tomorrow, data.forecast.maxtemp, 'max')
  
  -- Cloud cover
  device:emit_component_event(device.profile.components.tomorrow, cap_cloudcover.cloudcover({value=data.forecast.cloudcover.value, unit='%'}))
  
  -- Precip rate
  _emit_preciprate(device, device.profile.components.tomorrow, data.forecast.preciprate.value)
  
  -- Precip probability
  _emit_precipprob(device, device.profile.components.tomorrow, data.forecast.precipprob.value)
  --device:emit_component_event(device.profile.components.tomorrow, cap_precipprob.probability({value=data.forecast.precipprob.value, unit='%'}))

  -- Wind speed
  _emit_windspeed(device, device.profile.components.tomorrow, data.forecast.windspeed.value)
  
  -- Wind gust
  _emit_windspeed(device, device.profile.components.tomorrow, data.forecast.windgust.value, 'gust')

end

return  {
          emit_current = emit_current,
          emit_forecast = emit_forecast,
          _emit_summary = _emit_summary,
          _emit_precipprob = _emit_precipprob,
          _emit_dewpoint = _emit_dewpoint,
        }
