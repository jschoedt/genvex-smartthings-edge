local log = require "log"
local socket = require "cosock.socket"
local nabto = require "nabto.genvex_connection"

local discovery = {}

-- Cache for storing the discovery client
local discovery_client_cache = nil

function discovery.handle_discovery(driver)
  log.info("Starting Genvex device discovery...")

  -- 1. Create a temporary Nabto client just for discovery.
  local discovery_client = nabto.new(driver, "")
  
  -- Store the discovery client in cache for later retrieval
  discovery_client_cache = discovery_client

  -- 2. Start the client and send the discovery broadcast
  discovery_client:start()
  discovery_client:send_discovery()


  -- 3. Wait a few seconds for devices to respond to the broadcast
  socket.sleep(3)

  log.info("Discovered devices:")
  if next(discovery_client.discovered_devices) == nil then
    log.info("  <No devices found>")
  else
    -- 4. For each device found, cache the IP/port and create a SmartThings device
    for id, addr in pairs(discovery_client.discovered_devices) do
      log.info(string.format("  - Found device with ID: %s at %s:%s", id, addr[1], addr[2]))

      local metadata = {
        type = "LAN",
        profile = "genvex-hvac.v1",
        device_network_id = id,
        label = string.format("Genvex HVAC (%s)", id),
        vendor_provided_label = "Genvex HVAC (" .. id .. ")",
        manufacturer = "Genvex",
        model = "Optima", -- Or other model if detectable
      }

      -- This tells the Hub to add the new device.
      driver:try_create_device(metadata)
    end
  end

  log.info("Genvex device discovery finished.")
end

-- Function to retrieve the cached discovery client
function discovery.get_discovery_client()
  return discovery_client_cache
end


return discovery