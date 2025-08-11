# Genvex HVAC SmartThings Edge Driver

Control your Genvex HVAC system directly from the SmartThings app using a local, LAN-based Edge driver. The driver implements the Genvex device protocol described in the genvexnabto project and communicates over UDP on your local network.

- Protocol reference: https://github.com/superrob/genvexnabto
- Nabto platform (reference repo): https://github.com/nabto

## Features

- Thermostat mode: heat, cool, auto, off
- Heating and cooling setpoints
- Current temperature and humidity monitoring
- Fan speed control
- Automatic device discovery on the local network
- Manual refresh

## How It Works

- Local-only communication (no cloud hops) over UDP on port 5570
- Discovers compatible Genvex units on your LAN and exchanges protocol packets for status and control
- Based on the protocol as described in the genvexnabto project; see the references above for background

## Requirements

- A SmartThings Hub with Edge support
- A compatible Genvex HVAC unit connected to the same local network as the hub
- Stable LAN connectivity; multicast/broadcast must be allowed by your router/switch
- An authorized email registered for access to your Genvex/Nabto-enabled device

## Installation

1. Obtain the driver package (Edge driver).
2. Install it to your SmartThings Hub using your preferred method (for example, SmartThings CLI or Developer Workspace).
3. In the SmartThings app, add a device and run discovery; the driver should find your Genvex unit automatically.

Notes:
- Ensure your phone, hub, and Genvex device are on the same subnet/VLAN.
- If discovery fails, temporarily disable AP/client isolation or IGMP snooping that may block broadcasts.

## Authorization: Email Requirement

This driver requires an authorized email to communicate with the device.

- Register your email with your Genvex/Nabto-enabled unit (per your device/vendor instructions).
- After the device is added in the SmartThings app, open the device’s Settings and enter the same authorized email in the Email field.
- If the email is missing or incorrect, the connection will not be established and the device will not control the unit.

## Configuration

Most setups require no manual configuration beyond entering your authorized email. If your device isn’t discovered:

- Verify the Genvex unit is powered, on the same LAN, and reachable.
- Ensure your network allows UDP broadcast/response on port 5570.
- Reboot the hub and Genvex unit if necessary, then retry discovery.

## Capabilities Exposed

- Thermostat Mode
- Thermostat Heating Setpoint
- Thermostat Cooling Setpoint
- Temperature Measurement
- Relative Humidity Measurement
- Fan Speed
- Refresh

## Usage

- Adjust thermostat mode and setpoints from the device panel in SmartThings.
- Change fan speed if supported by your model.
- Use Refresh to request an immediate status update.

## Troubleshooting

- Device not found:
    - Confirm the hub and Genvex are on the same network and not separated by VLAN/firewall rules.
    - Check that your router isn’t blocking broadcasts or UDP traffic on port 5570.
- Controls not responding:
    - Ensure the authorized email is correctly set in the device’s Settings in the SmartThings app.
    - Use Refresh to resync state.
    - Power-cycle the Genvex unit and hub.
    - Verify the device remains reachable on the LAN (e.g., check DHCP leases).

## Development Notes

This driver follows the on-device protocol outlined in the genvexnabto repository and communicates via UDP port 5570. For deeper protocol insights and historical background, consult:
- genvexnabto: https://github.com/superrob/genvexnabto
- Nabto (reference repo): https://github.com/nabto

## Security and Privacy

- Local network communication only; no cloud proxying by the driver.
- Ensure your LAN is trusted. Consider placing IoT devices on a dedicated VLAN with appropriate firewall rules.

## License

Provided as-is, without warranty. Use at your own risk.

## Acknowledgments

- Protocol reference and background: genvexnabto project
- Nabto platform resources and documentation