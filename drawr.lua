dofile("table_show.lua")
dofile("urlcode.lua")

local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
local item_dir = os.getenv('item_dir')
local warc_file_base = os.getenv('warc_file_base')

if warc_file_base == nil then
  warc_file_base = "test"
end
if item_dir == nil then
  item_dir = "."
end
if wget == nil then
  wget = {}
  wget.callbacks = {}
end

local url_count = 0
local tries = 0
local downloaded = {}
local addedtolist = {}
local abortgrab = false

local ids = {}
local discovered = {}

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

local function read_file(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

local function allowed(url, parenturl)
  if string.match(url, "'+")
      or string.match(url, "[<>\\%*%$;%^%[%],%(%){}]")
      or string.match(url, "^https?://www%.w3%.org")
      or string.match(url, "^http://drawr%.net/[^/]*%.php$")
      or string.match(url, "^http://drawr%.net/api/")
      or string.match(url, "^http://drawr%.net/login%.php")
      or string.match(url, "^http://drawr%.net/faving%.php")
      or string.match(url, "^http://drawr%.net/bookmark%.php")
      or string.match(url, "^http://drawr%.net/feed%.php")
      or string.match(url, "^http://drawr%.net/favter%.php")
      or string.match(url, "^http://drawr%.net/embed%.php")
      or string.match(url, "^http://drawr%.net/[a-zA-Z0-9-_]+$")
      or string.match(url, "^http://drawr%.net/$")
      or string.match(url, "^http://drawr%.net/twitdrawr.php") then
    return false
  end

  if string.match(url, "^http://drawr%.net/")
      or string.match(url, "^http://img[0-9][0-9].drawr.net") then
    return true
  end

  return false
end


local function filter_downloaded(url)
  if downloaded[url] then
    return nil
  else
    return { url=url }
  end
end

local function check_add(urla)
  if (downloaded[url_] ~= true and addedtolist[url_] ~= true)
      and allowed(url_, origurl) then
    table.insert(urls, { url=url_ })
    addedtolist[url_] = true
    addedtolist[url] = true
  end
end

--------------------------------------------------------------------------------------------------

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]

  if string.match(url, "[<>\\%*%$;%^%[%],%(%){}\"]") then
    return false
  end

  if (downloaded[url] ~= true and addedtolist[url] ~= true)
      and (allowed(url, parent["url"]) or html == 0) then
    addedtolist[url] = true
    return true
  end
  
  return false
end

--------------------------------------------------------------------------------------------------

wget.callbacks.get_urls = function(file, url, is_css, iri)
  io.stdout:write("get_urls: " .. url .. "\n")
  io.stdout:flush()
  print("get_urls: " .. url .. "\n")

  local todo_urls = {}
  local html = nil
  
  downloaded[url] = true

  if allowed(url, nil) and not (string.match(url, "%.jpg$") or string.match(url, "%.png$") or string.match(url, "%.gz$")) then

    local html2 = read_file(file)
    if string.len(html2) == 0 then
      io.stdout:write("Empty Doc abort\n")
      io.stdout:flush()
      return {}
    end
    if string.match(url, "http://img[0-9][0-9]%.drawr%.net/draw/img/.*%.xml") then
      local srcHostID = string.sub(url, 11, 12)
      io.stdout:write("Checking xml on "..srcHostID.."\n")
      io.stdout:flush()
      for gz_uri in string.gmatch(html2, 'http[^\n]*%.gz') do
        local targetHostID = string.sub(gz_uri, 11, 12)
        if srcHostID ~= targetHostID then
          local gz_uri2 = string.gsub(gz_uri,targetHostID,srcHostID,1)
          io.stdout:write("Augment Hostname Missmatch "..srcHostID.." > "..targetHostID.."\n")
          io.stdout:flush()
          table.insert(todo_urls, filter_downloaded(gz_uri2))
        end
        io.stdout:write("Found new gz with link " .. gz_uri .. "\n")
        io.stdout:flush()
        table.insert(todo_urls, filter_downloaded(gz_uri))
      end
    end
    if string.match(url, "show%.php") then
      for userprofile in string.gmatch(html2, 'mgnRight10"><a href="/([a-zA-Z0-9_-]+)">') do
        if userprofile ~= username then 
          username = userprofile
          userprofilelink = "http://drawr.net/"..username
          table.insert(discovered, username)
          --io.stdout:write("Found new profile " .. userprofile .. " with link " .. userprofilelink .. "\n")
        end
      end
      local sn = string.match(html2, 'jsel_plyr_sn ="([a-zA-Z0-9_-%.]+)"')
      if sn then
        --io.stdout:write(sn .. "\n")
        drawrservername = sn
      end
      local plyrid = string.match(html2, 'jsel_plyr_uid="([0-9]+)"')
      if plyrid then
        --io.stdout:write(plyrid .. "\n")
        playeruid = plyrid
      end
      local plyrfn = string.match(html2, 'jsel_plyr_fn ="([a-zA-Z0-9]+)"')
      if plyrfn then
        --io.stdout:write(plyrfn .. "\n")
        playerfn = plyrfn
      end
      --io.stdout:write(drawrservername .. " " .. playeruid .. " " .. playerfn .. "\n")
      --io.stdout:write("Found play file " .. playfilelink .. "\n")
      --io.stdout:write("Found imag file " .. imagefilelink .. "\n")
      local thumbfilelink = "http://"..drawrservername.."/draw/img/"..playeruid.."/"..playerfn.."_150x150.png"
      local   pngfilelink = "http://"..drawrservername.."/draw/img/"..playeruid.."/"..playerfn..".png"
      local   xmlfilelink = "http://"..drawrservername.."/draw/img/"..playeruid.."/"..playerfn..".xml"
      local    gzfilelink = "http://"..drawrservername.."/draw/img/"..playeruid.."/"..playerfn..".gz"
      table.insert(todo_urls, filter_downloaded(thumbfilelink))
      table.insert(todo_urls, filter_downloaded(pngfilelink))
      table.insert(todo_urls, filter_downloaded(xmlfilelink))
      table.insert(todo_urls, filter_downloaded(gzfilelink))
      --os.execute("sleep 10")
    end
  end

  return todo_urls
end

--------------------------------------------------------------------------------------------------

wget.callbacks.httploop_result = function(url, err, http_stat)
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. "  \n")
  io.stdout:flush()

  if status_code == 302 and http_stat["newloc"] == "http://drawr.net/" then
    downloaded[url["url"]] = true
    downloaded[string.gsub(url["url"], "https?://", "http://")] = true
    return wget.actions.EXIT
  end

  if status_code >= 300 and status_code <= 399 then
    local newloc = string.match(http_stat["newloc"], "^([^#]+)")
    if string.match(newloc, "^//") then
      newloc = string.match(url["url"], "^(https?:)") .. string.match(newloc, "^//(.+)")
    elseif string.match(newloc, "^/") then
      newloc = string.match(url["url"], "^(https?://[^/]+)") .. newloc
    elseif not string.match(newloc, "^https?://") then
      newloc = string.match(url["url"], "^(https?://.+/)") .. newloc
    end
    if downloaded[newloc] == true or addedtolist[newloc] == true or not allowed(newloc, url["url"]) then
      tries = 0
      return wget.actions.EXIT
    end
  end
  
  if status_code >= 200 and status_code <= 399 then
    downloaded[url["url"]] = true
    downloaded[string.gsub(url["url"], "https?://", "http://")] = true
  end

  if abortgrab == true then
    io.stdout:write("ABORTING...\n")
    return wget.actions.ABORT
  end
  
  if status_code >= 500
      or (status_code >= 400 and status_code ~= 404)
      or status_code  == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    local maxtries = 10
    if not allowed(url["url"], nil) then
        maxtries = 2
    end
    if tries > maxtries then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if allowed(url["url"], nil) then
        return wget.actions.ABORT
      else
        return wget.actions.EXIT
      end
    else
      os.execute("sleep " .. math.floor(math.pow(2, tries)))
      tries = tries + 1
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end

--------------------------------------------------------------------------------------------------

wget.callbacks.finish = function(start_time, end_time, wall_time, numurls, total_downloaded_bytes, total_download_time)
  local file = io.open(item_dir..'/'..warc_file_base..'_data.txt', 'w')
  for n, profile in pairs(discovered) do
    file:write(profile .. "\n")
  end
  file:close()
end

--------------------------------------------------------------------------------------------------

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if abortgrab == true then
    return wget.exits.IO_FAIL
  end
  return exit_status
end
