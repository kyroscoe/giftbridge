-- GiftBridge.lua
local socket = require("socket.core")
local giftSock
local isConnected = false

local itemsAddress = {
  -- fill this with your itemID→RAM address map, e.g.
  [5] = 0x020243A2,  -- Poké Ball count
  [7] = 0x020243A4,  -- Potion count
  -- …
}

local function connect()
  giftSock = assert(socket.tcp())
  giftSock:settimeout(0)              -- non‐blocking
  local ok, err = giftSock:connect("127.0.0.1", 5000)
  if ok then
    isConnected = true
    console.log("[GiftBridge] Connected to Python listener")
  else
    console.log("[GiftBridge] Connection failed:", err)
  end
end

local function processLine(line)

  local cmd, id, amt = line:match("(%u+)_ITEM%s+(%d+)%s+(%d+)")
  id, amt = tonumber(id), tonumber(amt)
  local addr = itemsAddress[id]
  if not addr then
    console.log(string.format("[GiftBridge] Unknown itemID %d", id))
    return
  end

  local current = memory.read_u8(addr)
  if cmd == "ADD" then
    memory.write_u8(addr, current + amt)
    console.log(string.format("[GiftBridge] Added %d to item %d (new %d)", amt, id, current+amt))
  elseif cmd == "REMOVE" then
    memory.write_u8(addr, math.max(0, current - amt))
    console.log(string.format("[GiftBridge] Removed %d from item %d (new %d)", amt, id, math.max(0,current-amt)))
  end
end


local function startup()
  console.log("[GiftBridge] Starting up…")
  connect()
end


local function afterFrame()
  if not isConnected then
    connect()
    return
  end
  local line, err = giftSock:receive("*l")
  if line then
    processLine(line)
  elseif err ~= "timeout" then
    console.log("[GiftBridge] Socket error:", err)
    isConnected = false
    giftSock:close()
  end
end

return {
  name = "TikTok Gift → Item Bridge",
  author = "YourName",
  description = "Listens on TCP:5000 for gift events and updates item counts.",
  startup = startup,
  afterFrame = afterFrame
}
