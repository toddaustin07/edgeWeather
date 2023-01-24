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
  
  SmartThings Edge Weather Driver

--]]

-- Edge libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
--local cosock = require "cosock"                 -- just for time
local socket = require "cosock.socket"          -- just for time
local log = require "log"

-- Driver modules
local comms = require "comms"                   -- HTTP requests to fetch weather data
local emitter = require "emitter"               -- Update SmartThings device attributes

-- Weather source modules
local _darksky = require "darksky"
local _usgov = require "usgov"
local _fmi = require "fmi"
local _openweather = require "openweather"
local _underground = require "underground"

local wmodule = {
                  ['darksky'] = _darksky,
                  ['usgov'] = _usgov,
                  ['fmi'] = _fmi,
                  ['openw'] = _openweather,
                  ['under'] = _underground,
                }


-- Module variables
local thisDriver
local initialized = false

-- Custom capabilities
local cap_createdev = capabilities["partyvoice23922.createanother"]
local cap_refresh = capabilities["partyvoice23922.refresh"]


-- Validate format of proxy IP:port address
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
-- this may also be called by a periodic timer
local function refresh_device(device)

  local status, weatherdata
  local weathertable, pos, err
  local baseurl = device.preferences.proxyaddr .. '/api/forward?url='


  -- Get Current observations
  if device.preferences.url then
  
    local request_url
  
    if device.preferences.proxytype ~= 'none' then
  
      request_url = wmodule[device.preferences.wsource].modify_current_url(device.preferences.url)
    
      if device.preferences.proxytype == 'edge' then
        request_url = baseurl .. request_url
      end
    else
      request_url = device.preferences.url
    end
    
    status, weatherdata = comms.issue_request(device, "GET", request_url)

    if status == true then
    
      emitter.emit_current(device, wmodule[device.preferences.wsource].update_current(device, weatherdata))
    
    else
      log.warn (string.format('Current data fetch failed for device %s', device.label))
    end
    
    -- Get Forecast if different URL provided
    if device.preferences.furl ~= 'xxxxx' then
    
      if device.preferences.proxytype == 'edge' then
        request_url = baseurl .. device.preferences.furl
      else
        request_url = device.preferences.furl
      end
      status, weatherdata = comms.issue_request(device, "GET", request_url)
    end
    
    if status == true then
      emitter.emit_forecast(device, wmodule[device.preferences.wsource].update_forecast(device, weatherdata))
    else
      log.warn (string.format('Forecast data fetch failed for device %s', device.label))
    end
  end
end


local function create_device(driver)
  
  log.info("Creating Weather device")
    
  local MFG_NAME = 'SmartThings Community'
  local VEND_LABEL = 'Edge Weather'
  local MODEL = 'edgeweatherv1'
  local ID = 'edge_weather' .. '_' .. socket.gettime()
  local PROFILE = 'weather.v1g'

  -- Create device

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


end


-- Start automatic periodic refresh timer
local function restart_timer(driver, device)

  if device:get_field('periodictimer') then                                          -- just in case
    driver:cancel_timer(device:get_field('periodictimer'))
  end
  local periodic_timer = driver:call_on_schedule(device.preferences.refreshrate * 60,
    function()
      refresh_device(device)
    end, 'Refresh timer')
  device:set_field('periodictimer', periodic_timer)

end


-----------------------------------------------------------------------
--										COMMAND HANDLERS
-----------------------------------------------------------------------

local function handle_refresh(driver, device, command)

  log.info ('Refresh requested; command:', command.command)

  refresh_device(device)
  
end


local function handle_createdev(driver, device, command)

  create_device(driver)

end

------------------------------------------------------------------------
--                REQUIRED EDGE LIFECYCLE HANDLERS
------------------------------------------------------------------------

-- Lifecycle handler to initialize existing devices
local function device_init(driver, device)
  
  log.debug(device.id .. ": " .. device.device_network_id .. "> INITIALIZING")

  device:try_update_metadata({profile='weather.v1g'})

  initialized = true
  
  if (validate_address(device.preferences.proxyaddr)) and device.preferences.url ~= 'xxxxx' then
    refresh_device(device)
  
    if device.preferences.autorefresh == 'enabled' then
      restart_timer(driver, device)
    end
  else
    log.warn('Configuration required')
  end
end


-- Called when device was just created in SmartThings; all capability attributes MUST be initialized
local function device_added (driver, device)

  log.info(device.id .. ": " .. device.device_network_id .. "> ADDED")

  local initialize_current = {current={}}
  initialize_current.current =    {  
                                    summary     = {value=' '},
                                    temperature = {value=20},
                                    humidity    = {value=50},
                                    mintemp     = {value=20},
                                    maxtemp     = {value=20},
                                    preciprate  = {value=0},
                                    precipprob  = {value=0},
                                    pressure    = {value=1010},
                                    uv          = {value=0},
                                    cloudcover  = {value=50},
                                    dewpoint    = {value=20},
                                    windspeed   = {value=0},
                                    winddegrees = {value=0},
                                    windgust    = {value=0}
                                  }
                        
  emitter.emit_current(device, initialize_current)
                        
  local initialize_forecast = {forecast={}}
  initialize_forecast.forecast =  {
                                    summary     = {value=' '},
                                    temperature = {value=20},
                                    humidity    = {value=50},
                                    mintemp     = {value=20},
                                    maxtemp     = {value=20},
                                    preciprate  = {value=0},
                                    precipprob  = {value=0},
                                    cloudcover  = {value=50},
                                    windspeed   = {value=0},
                                    windgust    = {value=0}
                                  }
          
  emitter.emit_forecast(device, initialize_forecast)
  
end


-- Called when SmartThings thinks the device needs provisioning
local function device_doconfigure (_, device)

  -- Nothing to do here!

end


-- Called when device was deleted via mobile app
local function device_removed(driver, device)
  
  log.warn(device.id .. ": " .. device.device_network_id .. "> removed")
  
  local periodic_timer = device:get_field('periodictimer')
  if periodic_timer then
    driver:cancel_timer(periodic_timer)
  end
  
  local device_list = driver:get_devices()
  
  if #device_list == 0 then
    initialized = false
  end
  
end


local function handler_driverchanged(driver, device, event, args)

  log.debug ('*** Driver changed handler invoked ***')

end


-- Called when driver is being shut down either for reinstall or deletion
local function shutdown_handler(driver, event)

  log.info ('*** Driver being shut down ***')
  -- assume Edge destroys all outstanding timers & sockets

end


-- Called when user changes device settings preferences
local function handler_infochanged (driver, device, event, args)

  log.debug ('Info changed handler invoked')

    -- Did preferences change?
  if args.old_st_store.preferences then
    
     -- Examine each preference setting to see if it changed 
    
    local restarttimer = false
    
    if args.old_st_store.preferences.proxyaddr ~= device.preferences.proxyaddr then
      
      if (validate_address(device.preferences.proxyaddr)) then
        log.info ('Proxy address is valid')
      else
        log.warn ('Proxy address is INVALID')
      end
      
    elseif args.old_st_store.preferences.autorefresh ~= device.preferences.autorefresh then
      if device.preferences.autorefresh == 'disabled' and device:get_field('periodictimer') then
        driver:cancel_timer(device:get_field('periodictimer'))
        device:set_field('periodictimer', nil)
      elseif device.preferences.autorefresh == 'enabled' then
        restarttimer = true
      end
    
    elseif args.old_st_store.preferences.refreshrate ~= device.preferences.refreshrate then
      if device.preferences.autorefresh == 'enabled' then
        restarttimer = true
      end
    end 
    
    if restarttimer then; restart_timer(driver, device); end
    
  end  
     
end


-- Called whenever 'Scan for nearby devices' was initiated by user from mobile app
local function discovery_handler(driver, _, should_continue)
  
  if not initialized then
  
    create_device(driver)
    
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
  
    [cap_createdev.ID] = {
      [cap_createdev.commands.push.NAME] = handle_createdev,
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = handle_refresh,
    },
    [cap_refresh.ID] = {
      [cap_refresh.commands.push.NAME] = handle_refresh,
    },
  }
})

log.info ('Weather Driver v0.5 Started')

thisDriver:run()
