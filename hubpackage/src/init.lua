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
  
  SmartThings Edge Weather Driver (Darksky)

--]]

-- Edge libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local cosock = require "cosock"                 -- just for time
local socket = require "cosock.socket"          -- just for time
local json = require "dkjson"
local log = require "log"

-- Driver modules
local comms = require "comms"
local _darksky = require "darksky"
local _usgov = require "usgov"

local wmodule = {
                  ['darksky'] = _darksky,
                  ['usgov'] = _usgov,
                }


-- Module variables
local thisDriver
local initialized = false
local periodic_timer

-- Custom capabilities (global for access by other modules)

cap_summary = capabilities["partyvoice23922.summary"]
cap_refresh = capabilities["partyvoice23922.refresh"]
cap_precip = capabilities["partyvoice23922.precip"]
cap_precipprob = capabilities["partyvoice23922.precipprob"]
cap_barometer = capabilities["partyvoice23922.barometer"]
cap_cloudcover = capabilities["partyvoice23922.cloudcover"]
cap_dewpoint = capabilities["partyvoice23922.dewpoint"]
cap_windspeed = capabilities["partyvoice23922.windspeed5"]
cap_windbearing = capabilities["partyvoice23922.windbearing"]


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


local function validate_address(lanAddress)

  local valid = true
  
  local hostaddr = lanAddress:match('://(.+)$')
  if hostaddr == nil then; return false; end
  
  local ip = hostaddr:match('^(%d.+):')
  local port = tonumber(hostaddr:match(':(%d+)$'))
  
  if ip then
    local chunks = {ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}
    if #chunks == 4 then
      for _, v in pairs(chunks) do
        if tonumber(v) > 255 then 
          valid = false
          break
        end
      end
    else
      valid = false
    end
  else
    valid = false
  end
  
  if port then
    if type(port) == 'number' then
      if (port < 1) or (port > 65535) then 
        valid = false
      end
    else
      valid = false
    end
  else
    valid = false
  end
  
  if valid then
    return ip, port
  else
    return nil
  end
      
end

-- Go to weather API and get data, then update SmartThings
-- this is also called by a period timer, so can't receive device parameter
local function refresh_data()

  local device_list = thisDriver:get_devices()
  
  
  for _, device in ipairs(device_list) do

    local status, weatherjson
    local weathertable, pos, err
    local baseurl = device.preferences.proxyaddr .. '/api/forward?url='
  

    -- Get Current observations
    if device.preferences.url then
    
      local request_url
      if device.preferences.proxytype == 'edge' then
        request_url = baseurl .. device.preferences.url
      else
        request_url = device.preferences.url
      end
      status, weatherjson = comms.issue_request(device, "GET", request_url)

      if status == true then
      
        weathertable, pos, err = json.decode (weatherjson, 1, nil)
        
        wmodule[device.preferences.wsource].update_current(device, weathertable)
        
      end
      
      -- Get Forecast if different URL
      if device.preferences.furl ~= 'xxxxx' then
      
        if device.preferences.proxytype == 'edge' then
          request_url = baseurl .. device.preferences.furl
        else
          request_url = device.preferences.furl
        end
        status, weatherjson = comms.issue_request(device, "GET", request_url)
        if status == true then
          weathertable, pos, err = json.decode (weatherjson, 1, nil)
        end
      end
      
      if status == true then
        wmodule[device.preferences.wsource].update_forecast(device, weathertable)
      end
    end
  end
end


-----------------------------------------------------------------------
--										COMMAND HANDLERS
-----------------------------------------------------------------------


local function handle_refresh(driver, device, command)

  log.info ('Refresh requested')

  refresh_data()
    
end

------------------------------------------------------------------------
--                REQUIRED EDGE DRIVER HANDLERS
------------------------------------------------------------------------

-- Lifecycle handler to initialize existing devices AND newly discovered devices
local function device_init(driver, device)
  
  log.debug(device.id .. ": " .. device.device_network_id .. "> INITIALIZING")

  initialized = true
  
  if (validate_address(device.preferences.proxyaddr)) and device.preferences.url ~= 'xxxxx' then
    refresh_data()
  
    if device.preferences.autorefresh == 'enabled' then
      if periodic_timer then                                          -- just in case
        driver:cancel_timer(periodic_timer)
      end
      periodic_timer = driver:call_on_schedule(device.preferences.refreshrate * 60, refresh_data, 'Refresh timer')
    end
  end
end


-- Called when device was just created in SmartThings
local function device_added (driver, device)

  log.info(device.id .. ": " .. device.device_network_id .. "> ADDED")

  device:emit_component_event(device.profile.components.main, cap_summary.summary(' ', { visibility = { displayed = false } }))
  device:emit_component_event(device.profile.components.main, capabilities.temperatureMeasurement.temperature({value = 20, unit='C'}))
  device:emit_component_event(device.profile.components.main, capabilities.relativeHumidityMeasurement.humidity(50))
  device:emit_component_event(device.profile.components.main, cap_precip.precip({value=0, unit='mm/hr'}))
  device:emit_component_event(device.profile.components.main, cap_precipprob.probability({value=0, unit='%'}))
  device:emit_component_event(device.profile.components.main, capabilities.precipitationSensor.precipitationIntensity('none'))
  device:emit_component_event(device.profile.components.main, capabilities.atmosphericPressureMeasurement.atmosphericPressure(101))
  device:emit_component_event(device.profile.components.main, cap_barometer.pressure({value=1010, unit='mB'}))
  device:emit_component_event(device.profile.components.main, capabilities.ultravioletIndex.ultravioletIndex(0))
  device:emit_component_event(device.profile.components.main, cap_cloudcover.cloudcover({value=50, unit='%'}))
  device:emit_component_event(device.profile.components.main, cap_dewpoint.dewpoint(20))
  device:emit_component_event(device.profile.components.main, cap_windspeed.wSpeed({value=0, unit='m/s'}))
  device:emit_component_event(device.profile.components.main, cap_windbearing.windbearing(0))
  
  device:emit_component_event(device.profile.components.tomorrow, cap_summary.summary(' ', { visibility = { displayed = false } }))
  device:emit_component_event(device.profile.components.tomorrow, cap_precipprob.probability({value=0, unit='%'}))
  
end


-- Called when SmartThings thinks the device needs provisioning
local function device_doconfigure (_, device)

  -- Nothing to do here!

end


-- Called when device was deleted via mobile app
local function device_removed(_, device)
  
  log.warn(device.id .. ": " .. device.device_network_id .. "> removed")
  
  initialized = false
  
end


local function handler_driverchanged(driver, device, event, args)

  log.debug ('*** Driver changed handler invoked ***')

end


local function shutdown_handler(driver, event)

  log.info ('*** Driver being shut down ***')
  

end


local function handler_infochanged (driver, device, event, args)

  log.debug ('Info changed handler invoked')

    -- Did preferences change?
  if args.old_st_store.preferences then
    
     -- Examine each preference setting to see if it changed 
    
    if args.old_st_store.preferences.proxyaddr ~= device.preferences.proxyaddr then
      
      if (validate_address(device.preferences.proxyaddr)) then
        log.info ('Proxy address is valid')
      else
        log.warn ('Proxy address is INVALID')
      end
      
    elseif args.old_st_store.preferences.autorefresh ~= device.preferences.autorefresh then
      if device.preferences.autorefresh == 'disabled' and periodic_timer then
        driver:cancel_timer(periodic_timer)
        periodic_timer = nil
      elseif device.preferences.autorefresh == 'enabled' then
        if periodic_timer then                                          -- just in case
          driver:cancel_timer(periodic_timer)
        end
        periodic_timer = driver:call_on_schedule(device.preferences.refreshrate * 60, refresh_data, 'Refresh timer')
      end
    
    elseif args.old_st_store.preferences.refreshrate ~= device.preferences.refreshrate then
      if device.preferences.autorefresh == 'enabled' then
        if periodic_timer then
          driver:cancel_timer(periodic_timer)
        end
        periodic_timer = driver:call_on_schedule(device.preferences.refreshrate * 60, refresh_data, 'Refresh timer')
      end
    end 
  else
    log.warn ('Old preferences missing')
  end  
     
end


-- Create Weather Device
local function discovery_handler(driver, _, should_continue)
  
  if not initialized then
  
    log.info("Creating Web Request device")
    
    local MFG_NAME = 'SmartThings Community'
    local VEND_LABEL = 'Edge Weather'
    local MODEL = 'edgeweatherv1'
    local ID = 'ds_weather' .. '_' .. socket.gettime()
    local PROFILE = 'weather.v1'

    -- Create master device
	
		local create_device_msg = {
																type = "LAN",
																device_network_id = ID,
																label = VEND_LABEL,
																profile = PROFILE,
																manufacturer = MFG_NAME,
																model = MODEL,
																vendor_provided_label = VEND_LABEL,
															}
												
		assert (driver:try_create_device(create_device_msg), "failed to create weather device")
    
    log.debug("Exiting device creation")
    
  else
    log.info ('Weather device already created')
  end
end


-----------------------------------------------------------------------
--        DRIVER MAINLINE: Build driver context table
-----------------------------------------------------------------------
thisDriver = Driver("thisDriver", {
  discovery = discovery_handler,
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    driverSwitched = handler_driverchanged,
    infoChanged = handler_infochanged,
    doConfigure = device_doconfigure,
    removed = device_removed
  },
  driver_lifecycle = shutdown_handler,
  capability_handlers = {
  
    [cap_refresh.ID] = {
      [cap_refresh.commands.push.NAME] = handle_refresh,
    },

  }
})

log.info ('Weather Driver v0.1 Started')

thisDriver:run()
