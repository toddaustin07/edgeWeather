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
  
  SmartThings Edge Weather Driver - parse Finnish Metereological Institute

--]]

local capabilities = require "st.capabilities"
local xml2lua = require "xml2lua"
local xml_handler = require "xmlhandler.tree"
local log = require "log"

local common = require "common"


local function modify_current_url(current_url)

  return current_url .. '&starttime=' .. os.date('%Y-%m-%dT%H:%M:%SZ', os.time()-900)
end


local function getxml(weatherdata)

  local handler = xml_handler:new()
  local xml_parser = xml2lua.parser(handler)

  xml_parser:parse(weatherdata)
  
  if not handler.root then
    log.error ("Malformed XML")
    return
  end

  local parsed_xml = handler.root
  
  if not parsed_xml['wfs:FeatureCollection'] then
    log.error ("Unexpected XML (no FeatureCollection)")
    return
  end
  
  return parsed_xml

end

local function _tonum(value, valtype)

  if type(value) ~= 'number' then
    if valtype == 'temp' then
      return -999
    else
      return 0
    end
  else
    return value
  end

end

local function update_current(device, weatherdata)

  local weathertable = {}
  weathertable.current = {}

  local parsed_xml = getxml(weatherdata)
  if parsed_xml == nil then; return; end
  
  for _, member in ipairs(parsed_xml['wfs:FeatureCollection']['wfs:member']) do
  
    local itemvalue
    local datapoints = member['omso:PointTimeSeriesObservation']['om:result']['wml2:MeasurementTimeseries']['wml2:point']
    
    if common.is_array(datapoints) then
      itemvalue = tonumber(datapoints[#datapoints]['wml2:MeasurementTVP']['wml2:value'])
    else
      itemvalue = tonumber(datapoints['wml2:MeasurementTVP']['wml2:value'])
    end
    local id = member['omso:PointTimeSeriesObservation']['om:result']['wml2:MeasurementTimeseries']._attr['gml:id']
    
    -- Determine data item type
    
    if id:find('-t2m') or id:find('-Temperature') then
      weathertable.current.temperature = {value=_tonum(itemvalue, 'temp')}      
    elseif id:find('-rh') or id:find('-Humidity') then
      weathertable.current.humidity = {value=_tonum(itemvalue)}
    
    elseif id:find('-ws_10min') or id:find('-WindSpeedMS') then
      weathertable.current.windspeed = {value=_tonum(itemvalue)}
    
    elseif id:find('-wd_10min') or id:find('-WindDirection') then
      weathertable.current.winddegrees = {value=_tonum(itemvalue)}
      
    elseif id:find('-td') or id:find('-Dewpoint') then
      weathertable.current.dewpoint = {value=_tonum(itemvalue, 'temp')}
      
    elseif id:find('-p_sea') or id:find('-Pressure') then
      weathertable.current.pressure = {value=_tonum(itemvalue)}
    
    elseif id:find('-n_man') or id:find('-TotalCloudCover') then
      local cloudcover = math.floor((_tonum(itemvalue)/8) * 100)
      weathertable.current.cloudcover = {value=cloudcover}
    
    elseif id:find('-ri_10min') or id:find('-PrecipitationAmount') then
      log.debug ('FMI 10 min precip rate', itemvalue)
      local recentprecip = _tonum(itemvalue) * 6
      log.debug ('\t 1hr extrapolated:', recentprecip)
      weathertable.current.preciprate = {value=recentprecip}
    
    end
    
  end

  -- Received data does not include these values
  weathertable.current.summary = {value=' '}
  weathertable.current.precipprob = {value=0}
  weathertable.current.mintemp = {value=-999}
  weathertable.current.maxtemp = {value=-999}
  weathertable.current.windgust = {value=0}

  return weathertable

end

local function update_forecast(device, weatherdata)

  local weathertable = {}
  weathertable.forecast = {}

  local parsed_xml = getxml(weatherdata)
  if parsed_xml == nil then; return; end
  
  local dt = {}
  local noon_target = 1
  
  local memberlist = parsed_xml['wfs:FeatureCollection']['wfs:member']
  local strstarttime = memberlist[1]['omso:PointTimeSeriesObservation']['om:phenomenonTime']['gml:TimePeriod']['gml:beginPosition']
  dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec = strstarttime:match('(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z')
  log.debug ('Forecast period Start hour=', dt.hour)
  if tonumber(dt.hour) < 12 then
    noon_target = 2
  end
  
  for _, member in ipairs(memberlist) do
    
    local noon_count = 0
    local itemvalue
    
    local datapoints = member['omso:PointTimeSeriesObservation']['om:result']['wml2:MeasurementTimeseries']['wml2:point']
    local id = member['omso:PointTimeSeriesObservation']['om:result']['wml2:MeasurementTimeseries']._attr['gml:id']

    for i, datapoint in ipairs(datapoints) do
    
      local processthis = false
      local datapointtime = datapoint['wml2:MeasurementTVP']['wml2:time']
      dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec = datapointtime:match('(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z')
      if tonumber(dt.hour) == 12 then
        noon_count = noon_count + 1
        if noon_count == noon_target then; processthis = true; end
      elseif i == #datapoints then; processthis = true; end
      
      if processthis then
        log.debug (string.format('FMI forecast id=%s',id))
        local itemvalue = tonumber(datapoint['wml2:MeasurementTVP']['wml2:value'])
        log.debug (string.format('\tvalue=%s (%s)',itemvalue, datapointtime))
        
        -- Determine data item type
        
        if id:find('-t2m') or id:find('-Temperature') then
          weathertable.forecast.temperature = {value=_tonum(itemvalue, 'temp')}
          
        elseif id:find('-rh') or id:find('-Humidity') then
          weathertable.forecast.humidity = {value=_tonum(itemvalue)} 
        
        elseif id:find('-ws_10min') or id:find('-WindSpeedMS') then
          weathertable.forecast.windspeed = {value=_tonum(itemvalue)} 
        
        elseif id:find('-n_man') or id:find('-TotalCloudCover') then
        weathertable.forecast.cloudcover = {value=_tonum(itemvalue)} 
        
        elseif id:find('Precipitation1h') then
        
          local fcastprecip = _tonum(itemvalue)
          weathertable.forecast.preciprate = {value=fcastprecip}
        
        end
      
        break
      end
    end
  end

  -- received data does not include these fields
  weathertable.forecast.summary = {value=' '}
  weathertable.forecast.precipprob = {value=0}
  weathertable.forecast.mintemp = {value=-999}
  weathertable.forecast.maxtemp = {value=-999}
  weathertable.forecast.windgust = {value=0}

  return weathertable
  
end

return {
  modify_current_url = modify_current_url,
  update_current = update_current,
  update_forecast = update_forecast,
}
