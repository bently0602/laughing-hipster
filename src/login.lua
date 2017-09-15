local math = require "math"
local os = require "os"

local Settings = require "settings"

local gauth = require "libs.gauth"
local random = require "libs.random"
local CookieLib = require "libs.cookie"

local html_template = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Login</title>
<link href="https://fonts.googleapis.com/css?family=Raleway" rel="stylesheet">
<style>
body {
    font-family: 'Lato', Calibri, Arial, sans-serif;
    background: #fafafa;
    font-weight: 300;
    font-size: 15px;
    color: #333;
    -webkit-font-smoothing: antialiased;
    overflow-y: scroll;
    overflow-x: hidden;
}
input, textarea, keygen, select, button {
    text-rendering: auto;
    color: initial;
    letter-spacing: normal;
    word-spacing: normal;
    text-transform: none;
    text-indent: 0px;
    text-shadow: none;
    display: inline-block;
    text-align: start;
    margin: 0em 0em 0em 0em;
}
input {
    -webkit-appearance: textfield;
    background-color: white;
    -webkit-rtl-ordering: logical;
    user-select: text;
    cursor: auto;
    padding: 1px;
    border-width: 2px;
    border-style: inset;
    border-color: initial;
    border-image: initial;
}
input[type=submit] {
    width: 100%;
    padding: 8px 5px;
    /*border-radius: 5px;*/
    border: 1px solid #4e3043;
    box-shadow: inset 0 1px rgba(255,255,255,0.4), 0 2px 1px rgba(0,0,0,0.1);
    cursor: pointer;
    -webkit-transition: all 0.3s ease-out;
    -moz-transition: all 0.3s ease-out;
    -ms-transition: all 0.3s ease-out;
    -o-transition: all 0.3s ease-out;
    transition: all 0.3s ease-out;
    color: #000;
    /*text-shadow: 0 1px 0 rgba(0,0,0,0.3);*/
    font-size: 16px;
    font-weight: bold;
    font-family: 'Raleway', 'Lato', Arial, sans-serif;
    text-align: center;
}
*, *:after, *:before {
    -webkit-box-sizing: border-box;
    -moz-box-sizing: border-box;
    -ms-box-sizing: border-box;
    -o-box-sizing: border-box;
    box-sizing: border-box;
    padding: 0;
    margin: 0;
}
form {
    width: 300px;
    margin: 60px auto 30px;
    padding: 10px;
    position: relative;
    font-family: 'Raleway', 'Lato', Arial, sans-serif;
    color: white;
    text-shadow: 0 2px 1px rgba(0,0,0,0.3);
}
#info {
    width: 500px;
    margin: 60px auto 30px;
    padding: 10px;
    position: relative;
    font-family: 'Raleway', 'Lato', Arial, sans-serif;
    color: #222;
    font-size: 1.1em;
    text-shadow: 0 1px 1px rgba(0,0,0,0.3);
    text-align: center;
    word-wrap: break-word;
}
input[type=text]:hover, input[type=password]:hover {
    border-color: #333;
}
input[type=text], input[type=password] {
    width: 100%;
    padding: 8px 4px 8px 10px;
    margin-bottom: 15px;
    border: 1px solid #4e3043;
    border: 1px solid rgba(78,48,67, 0.8);
    background: rgba(0,0,0,0.05);
    border-radius: 2px;
    /*box-shadow: 0 1px 0 rgba(255,255,255,0.2), inset 0 1px 1px rgba(0,0,0,0.1);*/
    -webkit-transition: all 0.3s ease-out;
    -moz-transition: all 0.3s ease-out;
    -ms-transition: all 0.3s ease-out;
    -o-transition: all 0.3s ease-out;
    transition: all 0.3s ease-out;
    font-family: 'Raleway', 'Lato', Arial, sans-serif;
    color: #000;
    font-size: 13px;
}

#countdowntimer, #sessiondone {
    font-size: 1.5em;
    font-weight: bold;
    margin-top: 20px;
    margin-bottom: 20px;
}
</style>

<body>
!BODY!
</body>
</html>
]]

local login_html_body = [[
<form action="/login" method="post">
<input type="text" name="username" placeholder="username" autocomplete="off" value="">
<input type="password" name="password" placeholder="password" value="">
<input type="text" name="auth_code" placeholder="auth_code" autocomplete="off" value="">
<input type="submit" value="submit">
</form>
]]

local accesstoken_timer_timeout_js_code = '<script type="text/javascript">countDown = '..Settings["invalid_timeout"]..";</script>"
local accesstoken_timer_js_code = accesstoken_timer_timeout_js_code..[[

<div id="countdowntimer">00:00:00</div>
<div id="sessiondone" style="display: none;">session has expired</div>

<script type="text/javascript">
    sTime = new Date().getTime();

    function updateCountDownTime() {
        var cTime = new Date().getTime();
        var diff = cTime - sTime;
        var timeStr = '';
        var seconds = countDown - Math.floor(diff / 1000);
        if (seconds >= 0) {
            var hours = Math.floor(seconds / 3600);
            var minutes = Math.floor( (seconds-(hours*3600)) / 60);
            seconds -= (hours*3600) + (minutes*60);
            if ( hours < 10 ) {
                timeStr = "0" + hours;
            } else {
                timeStr = hours;
            }
            if ( minutes < 10 ){
                timeStr = timeStr + ":0" + minutes;
            } else {
                timeStr = timeStr + ":" + minutes;
            }
            if ( seconds < 10){
                timeStr = timeStr + ":0" + seconds;
            } else {
                timeStr = timeStr + ":" + seconds;
            }
            document.getElementById("countdowntimer").innerHTML = timeStr;
        } else {
            document.getElementById("countdowntimer").style.display="none";
            document.getElementById("sessiondone").style.display="block";
            clearInterval(counter);
        }
    }
    updateCountDownTime();
    counter = setInterval(updateCountDownTime, 500);
</script>
]]

local function process()
    ngx.header["Content-Type"] = "text/html"
    method_name = ngx.req.get_method()
    
    if method_name == "POST" then
        ngx.req.read_body()
        username = ""
        password = ""
        local args, err = ngx.req.get_post_args()
        if not args then
            ngx.log(ngx.ERR, "failed to get post args")
            return
        end
        
        username = args["username"]
        password = args["password"]
        auth_code = args["auth_code"]
        local access_tokens = ngx.shared.access_tokens
        
        
        if gauth.Check(Settings["auth_code_check"], auth_code) then
        
        else
            local bad_attempt_html = '<div id="info">'
            bad_attempt_html = bad_attempt_html.."<h3>bad auth code</h3>"                
            bad_attempt_html = bad_attempt_html..'<br /><br /><a href="/login">login</a>'
            bad_attempt_html = bad_attempt_html.."</div>"
            ngx.say(string.gsub(html_template, "!BODY!", bad_attempt_html))
            ngx.log(ngx.ERR, "bad auth code")
            return
        end
        
        
        
        local invalid_attempts, flags = access_tokens:get(username.."_invalidattempts")
        if invalid_attempts then
            if invalid_attempts >= Settings["max_invalid_attempts"] then
                local bad_attempt_html = '<div id="info">'
                bad_attempt_html = bad_attempt_html.."<h3>account locked</h3>"                
                bad_attempt_html = bad_attempt_html..'<br /><br /><a href="/login">login</a>'
                bad_attempt_html = bad_attempt_html.."</div>"
                ngx.say(string.gsub(html_template, "!BODY!", bad_attempt_html))
                ngx.log(ngx.ERR, "account locked: "..username)
                return
            end
        end
        

        
        if username == Settings["username_check"] and password == Settings["password_check"] then
            access_token = random.token(Settings["token_size"])
            access_tokens:set(username, access_token)
            access_tokens:set(username.."_invalidattempts", 0, Settings["invalid_timeout"])
            access_tokens:set(username.."_invalidaccesses", 0, Settings["invalid_timeout"])
            
            CookieLib.add_cookie_simple("xxxaccesstoken", access_token)
            CookieLib.add_cookie_simple("xxxusername", username)

            good_attempt_html = '<div id="info">'
            good_attempt_html = good_attempt_html.."<h3>you have successfully logged in</h3>"
            good_attempt_html = good_attempt_html..'<hr style="margin-top: 20px;" />'
            test_ret, test_ret_err = access_tokens:get(username)
            if not test_ret then
                ngx.say(test_ret_err)
            else
                good_attempt_html = good_attempt_html..'<b style="margin-top: 20px;display: block;">Access Token:</b>'..test_ret
            end
            
            good_attempt_html = good_attempt_html..accesstoken_timer_js_code
            
            good_attempt_html = good_attempt_html.."<hr />"
            good_attempt_html = good_attempt_html..'<br /><br /><a href="/login">logout</a>'
            good_attempt_html = good_attempt_html.."</div>"
            ngx.say(string.gsub(html_template, "!BODY!", good_attempt_html))
            ngx.log(ngx.ERR, "login successful "..username)
        else
            bad_attempt_html = '<div id="info">'
            bad_attempt_html = bad_attempt_html.."<h3>bad username and/or password</h3>"
            if username == Settings["username_check"] then
                local value, flags = access_tokens:get(username.."_invalidattempts")
                if not value then
                    access_tokens:set(username.."_invalidattempts", 1, Settings["invalid_timeout"])
                else
                    if value > 100000 then
                        access_tokens:set(username.."_invalidattempts", 100001, Settings["invalid_timeout"])
                    else
                        access_tokens:set(username.."_invalidattempts", 1 + value, Settings["invalid_timeout"])
                    end
                end
            else
                
            end
            
            bad_attempt_html = bad_attempt_html..'<br /><br /><a href="/login">login</a>'
            bad_attempt_html = bad_attempt_html.."</div>"
            ngx.say(string.gsub(html_template, "!BODY!", bad_attempt_html))
            local value, flags = access_tokens:get(username.."_invalidattempts")
            ngx.log(ngx.ERR, "bad login attempt " .. username .. " " .. value)
            return
        end
    else
        local cookie_username = ngx.var.cookie_xxxusername
        if cookie_username then
            local access_tokens = ngx.shared.access_tokens
            access_tokens:set(cookie_username, nil)
        end
        
        CookieLib.add_cookie_simple("xxxaccesstoken", "")
        CookieLib.add_cookie_simple("xxxusername", "")
            
        ngx.send_headers()
        x = CookieLib.get_cookies()
        
        if ngx.var.arg_sub == "gencode" then
            seckey = random.token(16)
            ngx.say(seckey.."<br />")
            ngx.say(gauth.GenCode(seckey, math.floor(os.time() / 30)).."<br />")
            ngx.say(ngx.time() + Settings["invalid_timeout"])
        else
            login_html = string.gsub(html_template, "!BODY!", login_html_body)
            ngx.say(login_html)            
        end
    end
end

return process