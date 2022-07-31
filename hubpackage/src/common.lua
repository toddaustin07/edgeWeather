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
  
  SmartThings Edge Weather Driver - common functions

--]]

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

return {
          convert_wind = convert_wind,
			 }
