local CookieLib = require "libs.cookie"
local Settings = require "settings"

local function process()
    local access_tokens = ngx.shared.access_tokens
    local cookie_accesstoken = ngx.var.cookie_xxxaccesstoken
    local cookie_username = ngx.var.cookie_xxxusername

    local access_token, flags = access_tokens:get(cookie_username)
    if not access_token then
        ngx.log(ngx.ERR, "no access token for request user: " .. cookie_username)
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end
    
    local invalidaccesses_count, flags = access_tokens:get(cookie_username.."_invalidaccesses")
    if invalidaccesses_count then
        if invalidaccesses_count > Settings["max_invalid_accesses"] then
            ngx.log(ngx.ERR, "max invalid accesses " .. cookie_username .. " " .. tostring(invalidaccesses_count))
            ngx.exit(ngx.HTTP_FORBIDDEN)
        end
    end
    
    if tostring(access_token) ~= cookie_accesstoken then
        if not invalidaccesses_count then
            access_tokens:set(cookie_username.."_invalidaccesses", 1, Settings["invalid_timeout"])
        else
            if value > 100000 then
                access_tokens:set(cookie_username.."_invalidaccesses", 100001, Settings["invalid_timeout"])
            else
                access_tokens:set(cookie_username.."_invalidaccesses", 1 + invalidaccesses_count, Settings["invalid_timeout"])
            end
        end      
        local invalidaccesses_count, flags = access_tokens:get(cookie_username.."_invalidaccesses")
        ngx.log(ngx.ERR, "_invalidaccesses for request user: " .. cookie_username .. " " .. invalidaccesses_count)
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end
    
    ngx.req.set_header("x-proxy-spec-username", cookie_username)
    return
end

return process