local capabilities = require "st.capabilities"
local socket = require "cosock.socket"
local log = require "log"
local command_handlers = require "command_handlers"
local discovery = require "discovery"

local BaseModel = require("nabto.basemodel")

local lifecycle_handler = {}



function lifecycle_handler.init(driver, device)
  log.info("[" .. device.id .. "] Initializing Genvex HVAC device from lifecycle.init")

  -- 1. Get the email from the device preferences
  local email = device.preferences.email
  if not email or email == "" then
    log.error("User email is not configured for this device. Connection will not be established.")
    return
  end
  log.info("Using authorized email: " .. email)

  local conn = device:get_field("connection")
  if not conn then
    log.error("No connection found for device: " .. device.id)
    return
  end

  conn.model_set_callback = function()
    log.info("Connection attempt finished. Connected: " .. tostring(conn.is_connected))

    conn:clear_update_handlers()

    -- add callback
    conn:register_update_handler(BaseModel.GenvexNabtoSetpointKey.FAN_SPEED, function(oldVal, newVal)
      log.debug(string.format("[%s] Fan speed: %d", device.id, newVal))
      device:emit_event(capabilities.fanSpeed.fanSpeed(newVal))
    end)

    conn:register_update_handler(BaseModel.GenvexNabtoDatapointKey.HUMIDITY, function(oldVal, newVal)
      log.debug(string.format("[%s] Humidity: %d%%", device.id, newVal))
      device:emit_event(capabilities.relativeHumidityMeasurement.humidity(newVal))
    end)

    conn:register_update_handler(BaseModel.GenvexNabtoDatapointKey.TEMP_EXHAUST, function(oldVal, newVal)
      log.debug(string.format("[%s] Temperature: %.1f°C", device.id, newVal))
      device:emit_event(capabilities.temperatureMeasurement.temperature({ value = newVal, unit = "C" }))
    end)

    conn:register_update_handler(BaseModel.GenvexNabtoSetpointKey.TEMP_SETPOINT, function(oldVal, newVal)
      log.debug(string.format("[%s] temperatureSetpoint: %.1f°C", device.id, newVal))
      device:emit_event(capabilities.temperatureSetpoint.temperatureSetpoint({ value = newVal, unit = "C" }))
    end)

    conn:register_update_handler(BaseModel.GenvexNabtoSetpointKey.REHEATING, function(oldVal, newVal)
      local capability = capabilities["circleconnect14093.toggleButton"]

      if newVal == 1 then
        device:emit_component_event(device.profile.components["reheating"], capability.state("on"))
      else
        device:emit_component_event(device.profile.components["reheating"], capability.state("off"))
      end
    end)
    
    -- Add the handler for humidity control state changes
    conn:register_update_handler(BaseModel.GenvexNabtoSetpointKey.HUMIDITY_CONTROL, function(oldVal, newVal)
        local capability = capabilities["circleconnect14093.toggleButton"]

      if newVal == 1 then
          device:emit_component_event(device.profile.components["humidity"], capability.state("on"))
        else
          device:emit_component_event(device.profile.components["humidity"], capability.state("off"))
        end
    end)



    conn:register_update_handler(BaseModel.GenvexNabtoSetpointKey.FILTER_DAYS, function(oldVal, newVal)
      -- Calculate filter life remaining as percentage
      -- Assume maximum filter life is 90 days (typical for HVAC filters)
      local maxFilterDays = 90
      if newVal > maxFilterDays then
        newVal = maxFilterDays
      end
      newVal = maxFilterDays - newVal

      local percentage = math.max(0, math.min(100, math.floor((newVal / maxFilterDays) * 100)))
      log.debug(string.format("[%s] Filter days left: %d, percentage: %d%%", device.id, newVal, percentage))
      device:emit_event(capabilities.filterState.filterLifeRemaining(percentage))
    end)

    conn:register_update_handler(BaseModel.GenvexNabtoDatapointKey.ALARM_OPTIMA270, function(oldVal, newVal)
      local capability = capabilities["circleconnect14093.dynamicStatusDisplay"]

      if newVal == 0 then
        device:emit_component_event(device.profile.components["status"],capability.statusText("OK"))
      else
        device:emit_component_event(device.profile.components["status"],capability.statusText("Error"))
      end
    end)

    conn:register_update_handler(BaseModel.GenvexNabtoDatapointKey.BYPASS_ACTIVE, function(oldVal, newVal)
      local capability = capabilities["circleconnect14093.dynamicStatusDisplay"]

      if newVal == 0 then
        device:emit_component_event(device.profile.components["mode"],capability.statusText("Generating"))
      else
        device:emit_component_event(device.profile.components["mode"],capability.statusText("Bypass active"))
      end

    end)


    -- IMPORTANT: Mark device as online and schedule tasks regardless of connection status.
    -- This ensures the device is responsive in the app and ready for the next attempt.
    -- This ensures the device is responsive in the app and ready for the next attempt.
    device:online()

    -- Cancel any existing timers to prevent duplicates before scheduling a new one.
    if device.thread and device.thread.timers then
      for timer in pairs(device.thread.timers) do
        device.thread:cancel_timer(timer)
      end
    end

    -- Schedule periodic refresh of device state
    device.thread:call_on_schedule(
            30, -- refresh interval
            function()
              command_handlers.refresh(driver, device, {})
            end
    )
    command_handlers.refresh(driver, device, {})

    log.info("Device is online and refresh timer is scheduled.")
  end

  conn.authorized_email = email
  conn:set_device(device.device_network_id)
end

function lifecycle_handler.infoChanged(driver, device, event, args)
  log.info("[" .. device.id .. "] infoChanged event received")
  local old_email = args.old_st_store.preferences.email
  local new_email = device.preferences.email

  -- If the email has changed, we need to re-do the entire initialization.
  if old_email ~= new_email then
    log.info("Authorized email has changed. Re-initializing device...")
    -- Call the new centralized initialization function.
    lifecycle_handler:init(driver, device)
  end
end

-- In the added function, set the default states for each component
function lifecycle_handler.added(driver, device)
  log.info("[" .. device.id .. "] Adding new Genvex HVAC device")

  -- Retrieve the cached discovery client
  local conn = discovery.get_discovery_client()
  if conn then
    device:set_field("connection", conn)
  else
    log.error("No cached discovery client found. Device may not function properly.")
  end

  -- set default states for capabilities
  device:emit_event(capabilities.fanSpeed.fanSpeed(0))
  device:emit_event(capabilities.relativeHumidityMeasurement.humidity(0))
  device:emit_event(capabilities.temperatureMeasurement.temperature({ value = 10, unit = "C" }))
  device:emit_event(capabilities.filterState.filterLifeRemaining(100))
  device:emit_event(capabilities.filterState.supportedFilterCommands({"resetFilter"}))

  -- Set default state for the reheating toggle
  local toggle_capability = capabilities["circleconnect14093.toggleButton"]
  device:emit_component_event(device.profile.components["reheating"], toggle_capability.label("Reheating"))
  device:emit_component_event(device.profile.components["reheating"], toggle_capability.state("off"))

  -- Set default state for the humidity toggle
  device:emit_component_event(device.profile.components["humidity"], toggle_capability.label("Humidity Control"))
  device:emit_component_event(device.profile.components["humidity"], toggle_capability.state("off"))

  -- Add default state for the new dynamic status display
  local status_capability = capabilities["circleconnect14093.dynamicStatusDisplay"]
  device:emit_component_event(device.profile.components["status"], status_capability.label("System Status"))
  device:emit_component_event(device.profile.components["mode"], status_capability.label("Operation mode"))

end

function lifecycle_handler.removed(_, device)
  log.info("[" .. device.id .. "] Removing Genvex HVAC device")

  local conn = device:get_field("connection")
  if conn then
    conn:stop()
  end

  -- Clean up any resources
  if device.thread and device.thread.timers then
    for timer in pairs(device.thread.timers) do
      device.thread:cancel_timer(timer)
    end
  end
end

return lifecycle_handler