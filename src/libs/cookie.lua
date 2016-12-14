local Settings = require "settings"

local CookieLib = {}

function CookieLib.get_cookies()
    local cookies = ngx.header["Set-Cookie"] or {}
    if type(cookies) == "string" then
        cookies = {cookies}
    end
    return cookies
end

function CookieLib.add_cookie(cookie)
    local cookies = CookieLib.get_cookies()
    table.insert(cookies, cookie)
    ngx.header['Set-Cookie'] = cookies
end

function CookieLib.remove_cookie(cookie_name)
  -- lookup if the cookie exists.
  local cookies, key, value = CookieLib.get_cookies()
 
  for key, value in ipairs(cookies) do
    local name = match(value, "(.-)=")
    if name == cookie_name then
      table.remove(cookies, key)
    end
  end
 
  ngx.header['Set-Cookie'] = cookies or {}
end

function CookieLib.add_cookie_simple(key, value)
  local cookie_string = key .. "=" .. value .. "; "
  cookie_string = cookie_string.."Path=/; "
  cookie_string = cookie_string.."Expires=" .. ngx.cookie_time(ngx.time() + Settings["invalid_timeout"]) .. "; "
  cookie_string = cookie_string.."Secure; "
  cookie_string = cookie_string.."Samesite=strict "
  CookieLib.add_cookie(cookie_string)
end

return CookieLib
