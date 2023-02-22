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
  
  SmartThings Edge Weather Driver - Communications code

--]]

local cosock = require "cosock"
local socket = require "cosock.socket"
local http = cosock.asyncify "socket.http"
local https = cosock.asyncify "ssl.https"
http.TIMEOUT = 8
https.TIMEOUT = 8
local ltn12 = require "ltn12"
local log = require "log"

local function issue_request(device, req_method, req_url, sendbody)

  local responsechunks = {}
  
  local content_length = 0
  if sendbody then
    content_length = string.len(sendbody)
  end
  
  
  
  local protocol = req_url:match('^(%a+):')
  local body, code, headers, status
  local setproxy, sethost
  
  if device.preferences.proxytype == 'generic' then
    setproxy = device.preferences.proxyaddr
    sethost = req_url
  elseif device.preferences.proxytype == 'edge' then
    sethost = req_url:match('forward%?url=(.+)$')
  elseif device.preferences.proxytype == 'none' then
    sethost = req_url:match('%?url=(.+)$')
  end
  
  if sethost then
    log.debug ('Weather URL:',sethost)
    sethost = (sethost..'/'):match('://([^/]+)/')
    log.debug ('\tHost=',sethost)
  else
    log.error ("Couldn't find weather URL host for:", req_url)
    return false
  end
  
  local sendheaders = {
                        ["Acccept"] = '*/*',
                        ["Host"] = sethost,
                        ["Content-Length"] = content_length,
                      }
  
  if protocol == 'https' then
  
    body, code, headers, status = https.request{
      method = req_method,
      url = req_url,
      headers = sendheaders,
      proxy = setproxy,               -- this is currently unsupported in Edge
      protocol = "any",
      options =  {"all"},
      verify = "none",
      source = ltn12.source.string(sendbody),
      sink = ltn12.sink.table(responsechunks)
     }

  else
    body, code, headers, status = http.request{
      method = req_method,
      url = req_url,
      headers = sendheaders,
      proxy = setproxy,
      source = ltn12.source.string(sendbody),
      sink = ltn12.sink.table(responsechunks)
     }
  end

  local response = table.concat(responsechunks)
  
  log.info(string.format("response code=<%s>, status=<%s>", code, status))
  
  local httpcode_str
  local httpcode_num
  
  if type(code) == 'number' then
    httpcode_num = code
  else
    httpcode_str = code
  end

  if httpcode_num then
    if (httpcode_num >= 200) and (httpcode_num < 300) then
      if response then
        return true, response
      else
        return false
      end
      
    else
      log.warn (string.format("HTTP %s request to %s failed with http code %s, status: %s", req_method, req_url, tostring(httpcode_num), status))
      return false
    end
  
  else
    
    if httpcode_str then
      if string.find(httpcode_str, "closed") then
        log.warn ("Socket closed unexpectedly")
      elseif string.find(httpcode_str, "refused") then
        log.warn("Connection refused: ", req_url)
      elseif string.find(httpcode_str, "timeout") then
        log.warn("HTTP request timed out: ", req_url)
      else
        log.error (string.format("HTTP %s request to %s failed with code: %s, status: %s", req_method, req_url, httpcode_str, status))
      end
    else
      log.warn ("No response code returned")
    end

  end

  return false
  
end

return {
  issue_request = issue_request,
}
