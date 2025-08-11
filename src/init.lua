-- Genvex HVAC Driver
-- Based on the protocol described at: https://github.com/superrob/genvexnabto

-- require st provided libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"

-- require custom handlers from driver package
local command_handlers = require "command_handlers"
local discovery = require "discovery"
local lifecycles = require('lifecycles')

-- create the driver object
local genvex_driver = Driver("genvexhvac", {
  discovery = discovery.handle_discovery,
  lifecycle_handlers = lifecycles,
  supported_capabilities = {
    capabilities.fanSpeed,
    capabilities.relativeHumidityMeasurement,
    capabilities.temperatureMeasurement,
    capabilities.temperatureSetpoint,
    capabilities.refresh,
    capabilities.filterState,
    capabilities["circleconnect14093.toggleButton"],
    capabilities["circleconnect14093.dynamicStatusDisplay"]
  },
  capability_handlers = {
    [capabilities.fanSpeed.ID] = {
      [capabilities.fanSpeed.commands.setFanSpeed.NAME] = command_handlers.set_fan_speed,
    },
    [capabilities.temperatureSetpoint.ID] = {
      [capabilities.temperatureSetpoint.commands.setTemperatureSetpoint.NAME] = command_handlers.set_temperature_setpoint,
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = command_handlers.refresh,
    },
    [capabilities.filterState.ID] = {
      [capabilities.filterState.commands.resetFilter.NAME] = command_handlers.reset_filter,
    },
    [capabilities["circleconnect14093.toggleButton"].ID] = {
        ["setState"] = command_handlers.set_state
    }
  }
})

-- run the driver
genvex_driver:run()