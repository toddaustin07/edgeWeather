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
  
  SmartThings Edge Weather Driver - common functions, including unit conversions

--]]

local log = require "log"

local function disptable(table, tab, maxlevels, currlevel)

	if not currlevel then; currlevel = 0; end
  currlevel = currlevel + 1
  for key, value in pairs(table) do
    if type(key) ~= 'table' then
      log.debug (tab .. '  ' .. key, value)
    else
      log.debug (tab .. '  ', key, value)
    end
    if (type(value) == 'table') and (currlevel < maxlevels) then
      disptable(value, '  ' .. tab, maxlevels, currlevel)
    end
  end
end


local function is_array(t)
  if type(t) ~= "table" then return false end
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then return false end
  end
  return true
end


local function convert_precip(precip, from_unit, to_unit)

  if from_unit == 'mmhr' then
    if to_unit == 'inhr' then
      return math.floor(precip / 25.4 * 10) / 10, 'in/hr'
    else
      return precip, 'mm/hr'
    end
  elseif from_unit == 'mhr' then
    if to_unit == 'mmhr' then
      return math.floor(precip * 1000 * 10) / 10, 'mm/hr'
    elseif to_unit == 'inhr' then
      return math.floor(precip * 39.37 * 10) / 10, 'in/hr'
    end
  elseif from_unit == 'inhr' then
    if to_unit == 'mmhr' then
      return math.floor(precip * 25.4 * 10) / 10, 'mm/hr'
    else
      return precip, 'in/hr'
    end
  end
end


local function convert_pressure(pressure, from_unit, to_unit)

  if from_unit == 'mbar' then
    if to_unit == 'kpa' then
      return math.floor(pressure / 10 * 10) / 10, 'kPa'
    elseif to_unit == 'inhg' then
      return math.floor(pressure / 33.864 * 10) / 10, 'inHg'
    else
      return pressure, 'mbar'
    end
    
  elseif from_unit == 'kpa' then
    if to_unit == 'mbar' then
      return math.floor(pressure * 10 * 10) / 10, 'mbar'
    elseif to_unit == 'inhg' then
      return math.floor(pressure / 3.386 * 10) / 10, 'inHg'
    else
      return pressure, 'kPa'
    end
    
  elseif from_unit == 'pa' then
    if to_unit == 'mbar' then
      return math.floor(pressure / 100 * 10) / 10, 'mbar'
    elseif to_unit == 'kpa' then
      return math.floor(pressure / 1000 * 10) / 10, 'kPa'
    elseif to_unit == 'inhg' then
      return math.floor(pressure / 3386 * 10) / 10, 'inHg'
    end

  elseif from_unit == 'inhg' then
    if to_unit == 'mbar' then
      return math.floor(pressure * 33.864 * 10) / 10, 'mbar'
    elseif to_unit == 'kpa' then
      return math.floor(pressure * 3.386 * 10) / 10, 'kPa'
    else
      return pressure, 'inHg'
    end
  end
end


local function convert_wind(speed, from_unit, to_unit)

  if from_unit == 'mpsec' then
    if to_unit == 'knots' then
      return math.floor(speed * 1.94384 * 10) / 10, 'kn'
    
    elseif to_unit == 'mph' then
      return math.floor(speed * 2.23694  * 10) / 10, 'mph'
    
    elseif to_unit == 'kph' then
      return math.floor(speed * 3.6  * 10) / 10, 'km/h'
      
    else
      return speed, 'm/s'
    end
  
  elseif from_unit == 'knots' then
    if to_unit == 'mpsec' then
      return math.floor(speed / 1.944 * 10) / 10, 'm/s'

    elseif to_unit == 'mph' then
      return math.floor(speed * 1.15078 * 10) / 10, 'mph'
    
    elseif to_unit == 'kph' then
      return math.floor(speed * 1.852 * 10) / 10, 'km/h'
      
    else
      return speed, 'kn'
    end
  
  elseif from_unit == 'mph' then
    if to_unit == 'knots' then
      return math.floor(speed / 1.151 * 10) / 10, 'kn'
    
    elseif to_unit == 'mpsec' then
      return math.floor(speed / 2.237 * 10) / 10, 'm/s'
      
    elseif to_unit == 'kph' then
      return math.floor(speed * 1.60934 * 10) / 10, 'km/h'
    
    else
      return speed, 'mph'
    end
  
  elseif from_unit == 'kph' then
    if to_unit == 'knots' then
      return math.floor(speed / 1.852 * 10) / 10, 'kn'
    
    elseif to_unit == 'mph' then
      return math.floor(speed / 1.609 * 10) / 10, 'mph'
    
    elseif to_unit == 'mpsec' then
      return math.floor(speed / 3.6 * 10) / 10, 'm/s'
    
    else
      return speed, 'km/h'
    end
  end
end

local function get_winddir(device, compass_reading)

  if device.preferences.winddir == '16dirs' then

    if compass_reading == 0 then return ('N')
    elseif compass_reading > 0 and compass_reading < 45 then return ('NNE')
    elseif compass_reading == 45 then return ('NE')
    elseif compass_reading > 45 and compass_reading < 90 then return ('ENE')
    elseif compass_reading == 90 then return ('E')
    elseif compass_reading > 90 and compass_reading < 135 then return ('ESE')
    elseif compass_reading == 135 then return ('SE')
    elseif compass_reading > 135 and compass_reading < 180 then return ('SSE')
    elseif compass_reading == 180 then return ('S')
    elseif compass_reading > 180 and compass_reading < 225 then return ('SSW')
    elseif compass_reading == 225 then return ('SW')
    elseif compass_reading > 225 and compass_reading < 270 then return ('WSW')
    elseif compass_reading == 270 then return ('W')
    elseif compass_reading > 270 and compass_reading < 315 then return ('WNW')
    elseif compass_reading == 315 then return ('NW')
    elseif compass_reading > 315 and compass_reading < 360 then return ('NNW')
    end
    
  else
    
    if compass_reading >= 0 and compass_reading <= 22.5 then return ('N')
    elseif compass_reading > 22.5 and compass_reading <= 67.5 then return ('NE')
    elseif compass_reading > 67.5 and compass_reading <= 112.5 then return ('E')
    elseif compass_reading > 112.5 and compass_reading <= 157.5 then return ('SE')
    elseif compass_reading > 157.5 and compass_reading <= 202.5 then return ('S')
    elseif compass_reading > 202.5 and compass_reading <= 247.5 then return ('SW')
    elseif compass_reading > 247.5 and compass_reading <= 292.5 then return ('W')
    elseif compass_reading > 292.5 and compass_reading <= 337.5 then return ('NW')
    elseif compass_reading > 337.5 and compass_reading <= 359 then return ('N')
    end
  end
end

return {
          is_array = is_array,
          convert_pressure = convert_pressure,
          convert_precip = convert_precip,
          convert_wind = convert_wind,
          disptable = disptable,
          get_winddir = get_winddir,
			 }
