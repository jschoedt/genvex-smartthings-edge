-- Genvex HVAC Command Handlers
local log = require "log"
local capabilities = require "st.capabilities"

local BaseModel = require("nabto.basemodel")

local command_handlers = {}


-- Handler for fan speed command
function command_handlers.set_fan_speed(driver, device, command)
  local speed = command.args.speed
  log.info(string.format("[%s] Setting fan speed to %d", device.id, speed))


  local conn = device:get_field("connection")

  local success = conn:set_setpoint(BaseModel.GenvexNabtoSetpointKey.FAN_SPEED, speed)
  if success then
    -- Update the device state
    device:emit_event(capabilities.fanSpeed.fanSpeed(speed))
    log.info(string.format("[%s] Successfully set fan speed to %d", device.id, speed))
  else
    log.error(string.format("[%s] Failed to set fan speed to %d", device.id, speed))
  end
end

-- Handler for temperature setpoint command
function command_handlers.set_temperature_setpoint(driver, device, command)
  local setpoint = command.args.setpoint
  log.info(string.format("[%s] Setting temperature setpoint to %.1f°C", device.id, setpoint))

  local conn = device:get_field("connection")
  if not conn then
    log.error(string.format("[%s] No connection available for temperature setpoint", device.id))
    return
  end

  local success = conn:set_setpoint(BaseModel.GenvexNabtoSetpointKey.TEMP_SETPOINT, setpoint)
  if success then
    -- Update the device state
    device:emit_event(capabilities.temperatureSetpoint.temperatureSetpoint({ value = setpoint, unit = "C" }))
    log.info(string.format("[%s] Successfully set temperature setpoint to %.1f°C", device.id, setpoint))
  else
    log.error(string.format("[%s] Failed to set temperature setpoint to %.1f°C", device.id, setpoint))
  end
end

-- Handler for filter reset command
function command_handlers.reset_filter(driver, device, command)
  log.info(string.format("[%s] Resetting filter", device.id))

  local conn = device:get_field("connection")
  if not conn then
    log.error(string.format("[%s] No connection available for filter reset", device.id))
    return
  end

  local success = conn:set_setpoint(BaseModel.GenvexNabtoSetpointKey.FILTER_RESET, 1)
  if success then
    -- Reset filter life to 100% immediately
    device:emit_event(capabilities.filterState.filterLifeRemaining(100))
    log.info(string.format("[%s] Successfully reset filter", device.id))
  else
    log.error(string.format("[%s] Failed to reset filter", device.id))
  end
end

-- Handler for refresh command
function command_handlers.refresh(driver, device, command)
  local conn = device:get_field("connection")
  if not conn then
    return
  end

  log.info(string.format("[%s] Refreshing device state", device.id))
  conn:refresh()

end

-- Handler for the custom toggle button's setState command
function command_handlers.set_state(driver, device, command)
  local target_state = command.args.state -- "on" or "off"
  local component_id = command.component

  log.info(string.format("[%s] Component '%s' requested state '%s'", device.id, component_id, target_state))

  local conn = device:get_field("connection")
  if not conn then
    log.error(string.format("[%s] No connection available for setState", device.id))
    return
  end

  local nabto_value = (target_state == "on") and 1 or 0
  local setpoint_key

  if component_id == "reheating" then
    setpoint_key = BaseModel.GenvexNabtoSetpointKey.REHEATING
  elseif component_id == "humidity" then
    setpoint_key = BaseModel.GenvexNabtoSetpointKey.HUMIDITY_CONTROL
  else
    log.error(string.format("Unknown component ID for setState: %s", component_id))
    return
  end

  local success = conn:set_setpoint(setpoint_key, nabto_value)
  if success then
    local capability = capabilities["circleconnect14093.toggleButton"]
    device:emit_component_event(device.profile.components[component_id], capability.state(target_state))
    log.info(string.format("[%s] Successfully sent command for component %s", device.id, component_id))
  else
    log.error(string.format("[%s] Failed to send command for component %s", device.id, component_id))
  end
end

function command_handlers.set_status(driver, device, command)
  local target_state = command.args.state
  local component_id = command.component

  log.info(string.format("[%s] Component '%s' requested state '%s'", device.id, component_id, target_state))

  local conn = device:get_field("connection")
  if not conn then
    log.error(string.format("[%s] No connection available for setState", device.id))
    return
  end

  if component_id == "mode" then
    setpoint_key = BaseModel.GenvexNabtoSetpointKey.REHEATING
  elseif component_id == "status" then
    setpoint_key = BaseModel.GenvexNabtoSetpointKey.HUMIDITY_CONTROL
  else
    log.error(string.format("Unknown component ID for setState: %s", component_id))
    return
  end

  local success = conn:set_setpoint(setpoint_key, nabto_value)
  if success then
    local capability = capabilities["circleconnect14093.toggleButton"]
    device:emit_component_event(device.profile.components[component_id], capability.state(target_state))
    log.info(string.format("[%s] Successfully sent command for component %s", device.id, component_id))
  else
    log.error(string.format("[%s] Failed to send command for component %s", device.id, component_id))
  end
end

return command_handlers