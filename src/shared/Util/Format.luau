--!strict
-- Number and time formatting shared by server labels and client UI.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1000 -> "1K", 1500 -> "1.5K", 1e6 -> "1M", 25e15 -> "25Qa".
function Format.abbreviate(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local whole = math.floor(n)
		return (if negative then "-" else "") .. tostring(whole)
	end
	local idx = 1
	while n >= 1000 and idx < #SUFFIXES do
		n /= 1000
		idx += 1
	end
	local text: string
	if n >= 100 then
		text = string.format("%d", math.floor(n))
	elseif n >= 10 then
		text = string.format("%.1f", math.floor(n * 10) / 10)
	else
		text = string.format("%.2f", math.floor(n * 100) / 100)
	end
	-- trim trailing zeros / dot ("1.50" -> "1.5", "1.00" -> "1")
	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	return (if negative then "-" else "") .. text .. SUFFIXES[idx]
end

-- "1,234,567"
function Format.commas(n: number): string
	local whole = tostring(math.floor(math.abs(n)))
	local out = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	out = out:gsub("^,", "")
	return (if n < 0 then "-" else "") .. out
end

-- 75 -> "1:15", 3661 -> "1:01:01"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds + 0.5))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- 75 -> "1m 15s", 5 -> "5s"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds + 0.5))
	if seconds < 60 then
		return string.format("%ds", seconds)
	end
	local m = seconds // 60
	local s = seconds % 60
	if m < 60 then
		return if s > 0 then string.format("%dm %ds", m, s) else string.format("%dm", m)
	end
	local h = m // 60
	m = m % 60
	return if m > 0 then string.format("%dh %dm", h, m) else string.format("%dh", h)
end

function Format.coins(n: number): string
	return Format.abbreviate(n) .. " Coins"
end

function Format.cps(n: number): string
	return Format.abbreviate(n) .. "/s"
end

function Format.percent(fraction: number): string
	return string.format("%d%%", math.floor(fraction * 100 + 0.5))
end

function Format.date(unix: number): string
	if unix <= 0 then
		return "-"
	end
	local d = os.date("!*t", unix)
	return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end

return Format
