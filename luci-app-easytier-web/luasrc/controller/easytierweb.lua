
module("luci.controller.easytierweb", package.seeall)

-- 安全执行命令并返回结果
local function safe_exec(cmd)
	local handle = io.popen(cmd)
	if not handle then return "" end
	local result = handle:read("*all") or ""
	handle:close()
	return result:gsub("[\r\n]+$", "")
end

-- 安全读取文件内容
local function safe_read_file(path)
	local file = io.open(path, "r")
	if not file then return nil end
	local content = file:read("*all")
	file:close()
	return content
end

-- 计算运行时长
local function calc_uptime(start_time_file)
	local content = safe_read_file(start_time_file)
	if not content or content == "" then return "" end
	
	local start_time = tonumber(content:match("%d+"))
	if not start_time then return "" end
	
	local now = os.time()
	local elapsed = now - start_time
	
	local days = math.floor(elapsed / 86400)
	local hours = math.floor((elapsed % 86400) / 3600)
	local mins = math.floor((elapsed % 3600) / 60)
	local secs = elapsed % 60
	
	local result = ""
	if days > 0 then result = days .. "天 " end
	result = result .. string.format("%02d小时%02d分%02d秒", hours, mins, secs)
	return result
end

function index()
	entry({"admin", "vpn", "easytierweb"}, alias("admin", "vpn", "easytierweb", "easytierweb"),_("EasyTier Web Console"), 46).dependent = true
	entry({"admin", "vpn", "easytierweb", "easytierweb"}, cbi("easytierweb"),_("EasyTier Web Console"), 48).leaf = true
	entry({"admin", "vpn", "easytierweb", "web_status"}, call("web_status")).leaf = true
	entry({"admin", "vpn", "easytierweb", "get_wlog"}, call("get_wlog")).leaf = true
	entry({"admin", "vpn", "easytierweb", "clear_wlog"}, call("clear_wlog")).leaf = true
end

function web_status()
	local e = {}
	local sys  = require "luci.sys"
	local nixio = require "nixio"
	local uci  = require "luci.model.uci".cursor()
	local port = tonumber(uci:get_first("easytierweb", "easytierweb", "html_port"))
	e.wrunning = luci.sys.call("pgrep easytier-web >/dev/null") == 0
	e.port = (port or 0)
	
	-- 使用 Lua 原生计算运行时长
	e.etwebsta = calc_uptime("/tmp/easytierweb_time")

	local command4 = io.popen('test ! -z "`pidof easytier-web`" && (top -b -n1 | grep -E "$(pidof easytier-web)" 2>/dev/null | grep -v grep | awk \'{for (i=1;i<=NF;i++) {if ($i ~ /easytier-web/) break; else cpu=i}} END {print $cpu}\')')
	e.etwebcpu = command4:read("*all")
	command4:close()
	
	local command5 = io.popen("test ! -z `pidof easytier-web` && (cat /proc/$(pidof easytier-web | awk '{print $NF}')/status | grep -w VmRSS | awk '{printf \"%.2f MB\", $2/1024}')")
	e.etwebram = command5:read("*all")
	command5:close()
	
	local easytier_web = "/usr/bin/easytier-web"
	if nixio.fs.stat(easytier_web) and nixio.fs.access(easytier_web, "x") then
		e.etwtag = safe_exec(easytier_web ..  " -V | sed 's/^[^0-9]*//'")
	else
		e.etwtag = ""
	end
	
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function get_wlog()
	local log = ""
	local files = {"/tmp/easytierweb.log"}
	for i, file in ipairs(files) do
		if luci.sys.call("[ -f '" .. file .. "' ]") == 0 then
			log = log .. luci.sys.exec("sed 's/\\x1b\\[[0-9;]*m//g' " .. file)
		end
	end
	luci.http.write(log)
end

function clear_wlog()
	luci.sys.call("echo '' >/tmp/easytierweb.log")
end
