dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')

local downloaded = {}
local addedtolist = {}
local elist = {}

local api1 = "a"

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]
  local itemvalue = string.gsub(item_value, "%-", "%%-")
  
  if downloaded[url] == true or addedtolist[url] == true then
    return false
  end
  
  if item_type == "account" and (downloaded[url] ~= true or addedtolist[url] ~= true) then
    if string.match(url, "friendfeed%.com/"..itemvalue) or string.match("friendfeed%-media%.com") then
      return true
    elseif html == 0 then
      return true
    else
      return false
    end
  end
  
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil
  local itemvalue = string.gsub(item_value, "%-", "%%-")
  
  local function check(url)
    if (downloaded[url] ~= true and addedtolist[url] ~= true) and not (string.match(url, "&amp;ncursor") or string.match(url, "&ncursor") or string.match(url, "&amp;pcursor") or string.match(url, "&pcursor") or string.match(url, "amp;amp;")) then
      table.insert(urls, { url=url })
      addedtolist[url] = true
    elseif string.match(url, "&amp;ncursor") or string.match(url, "&ncursor") or string.match(url, "&amp;pcursor") or string.match(url, "&pcursor") or string.match(url, "amp;amp;") then
      local newurl = string.match(url, "(https?://[^&]+)&")
      table.insert(urls, { url=newurl })
      addedtolist[newurl] = true
    end
  end
  
  if item_type == "account" then
    if string.match(url, "&") then
      local newurl = string.match(url, "(https?://[^&]+)&")
      check(newurl)
    end
    if string.match(url, "%?") then
      local newurl = string.match(url, "(https?://[^%?]+)%?")
      check(newurl)
    end
    if string.match(url, "friendfeed%.com/"..itemvalue) or string.match(url, "friendfeed%-api%.com") then
      html = read_file(file)
      for newurl in string.gmatch(html, '"(/[^"]+)"') do
        if string.match(newurl, "/"..itemvalue) or string.match(newurl, "/static") then
          if string.match(newurl, "&amp;ncursor=") then
            local nurl = "http://friendfeed.com"..string.match(newurl, "(/[^&]+)&amp;ncursor=")
            check(nurl)
          elseif string.match(newurl, "&ncursor=") then
            local nurl = "http://friendfeed.com"..string.match(newurl, "(/[^&]+)&ncursor=")
            check(nurl)
          else
            local nurl = "http://friendfeed.com"..newurl
            check(nurl)
          end
        end
      end
      for newurl in string.gmatch(html, '"(https?://[^"]+)"') do
        if string.match(newurl, "friendfeed%-api%.com") or string.match(newurl, "friendfeed%-media%.com") or string.match(newurl, "friendfeed%.com/"..itemvalue) then
          check(newurl)
        end
      end
      for new in string.gmatch(html, 'id="(e-[^"]+" eid="[^"]+)"') do
        local newurl = string.gsub(string.gsub(new, 'e%-', "http://friendfeed.com/e/"), '" eid="', "/c/")
        check(newurl)
      end
      if string.match(url, "friendfeed%.com/e/[0-9a-z]+") then
        local newurl = "http://friendfeed-api.com/v2/entry/e/"..string.match(url, "friendfeed%.com/e/([0-9a-z]+)")
        check(newurl)
      end
      for newurl in string.gmatch(html, '"id": "([^"]+)"') do
        if string.match(newurl, "[^/]+/[^/]+") then
          local nurl = "http://friendfeed.com/"..newurl
          check(nurl)
        end
      end
    end
    if string.match(url, "https?://friendfeed%-api%.com/v2/feed/"..itemvalue.."%?pretty=1&num=100&start=[0-9]+&hidden=1&raw=1") then
      html = read_file(file)
      if html ~= api1 then
        api1 = html
        local start = string.match(url, "https?://friendfeed%-api%.com/v2/feed/"..itemvalue.."%?pretty=1&num=100&start=([0-9]+)&hidden=1&raw=1")
        if start ~= 10000 then
          local nstart = start + 100
          local newurl = "http://friendfeed-api.com/v2/feed/"..item_value.."?pretty=1&num=100&start="..nstart.."&hidden=1&raw=1"
          check(newurl)
        end
      end
    end
  end
  
  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  local status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()
  
  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end
  
  if status_code == 301 and string.match(url["url"], "friendfeed%.com/e/[^/]+/") and elist[string.match(url["url"], "friendfeed%.com/e/([^/]+)/")] == true then
    return wget.actions.EXIT
  elseif status_code == 301 and string.match(url["url"], "friendfeed%.com/e/[^/]+/") and elist[string.match(url["url"], "friendfeed%.com/e/([^/]+)/")] ~= true then
    elist[string.match(url["url"], "friendfeed%.com/e/([^/]+)/")] = true
    return wget.actions.NOTHING
  elseif status_code == 301 and string.match(url["url"], "friendfeed%.com/e/.+") and elist[string.match(url["url"], "friendfeed%.com/e/(.+)")] == true then
    return wget.actions.EXIT
  elseif status_code == 301 and string.match(url["url"], "friendfeed%.com/e/.+") and elist[string.match(url["url"], "friendfeed%.com/e/(.+)")] ~= true then
    elist[string.match(url["url"], "friendfeed%.com/e/(.+)")] = true
    return wget.actions.NOTHING
  elseif status_code == 403 and (string.match(url["url"], "friendfeed%.com") or string.match(url["url"], "friendfeed%-media%.com") or string.match(url["url"], "friendfeed%-api%.com")) then
    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 20")

    tries = tries + 1

    if tries >= 3 and string.match(url["url"], "friendfeed%-media%.com") then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      return wget.actions.EXIT
    elseif tries >= 10 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  elseif status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 403) then
    if not (string.match(url["url"], "friendfeed%.com") or string.match(url["url"], "friendfeed%-grab%.com")) then
      return wget.actions.EXIT
    end

    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 1")

    tries = tries + 1

    if tries >= 20 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  elseif status_code == 0 then
    if not (string.match(url["url"], "friendfeed%.com") or string.match(url["url"], "friendfeed%-grab%.com")) then
      return wget.actions.EXIT
    end

    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 10")
    
    tries = tries + 1

    if tries >= 10 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  -- We're okay; sleep a bit (if we have to) and continue
  -- local sleep_time = 0.1 * (math.random(75, 1000) / 100.0)
  local sleep_time = 0

  --  if string.match(url["host"], "cdn") or string.match(url["host"], "media") then
  --    -- We should be able to go fast on images since that's what a web browser does
  --    sleep_time = 0
  --  end

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end
