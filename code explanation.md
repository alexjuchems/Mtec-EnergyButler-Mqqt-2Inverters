# Modbus-to-MQTT Bridge for MTEC Inverters

A Python script that reads Modbus TCP registers from solar inverters and publishes them to an MQTT broker with Home Assistant auto-discovery.

---

## Overview

```yaml
purpose: >
  Continuously polls Modbus TCP registers from one or more solar inverters,
  decodes the raw values, and publishes them to an MQTT broker. Home Assistant
  auto-discovery is used so sensors appear automatically without manual YAML
  configuration.

input_files:
  config.yaml: >
    Defines MQTT broker connection (host, port, credentials, base topic)
    and a list of inverters with their IP address, port, and Modbus slave ID.
  registers.yaml: >
    Defines every register to read — including Modbus address, data type,
    scaling factor, unit, MQTT topic suffix, polling group, and
    Home Assistant metadata (device class, state class, value template).
```

## Startup Sequence

```yaml
step_1_load_config:
  description: >
    Reads config.yaml and registers.yaml from the working directory.

step_2_connect_mqtt:
  description: >
    Creates a global MQTT client and connects to the broker.
    Waits for the network to be reachable first (useful when the script
    starts at boot before networking is fully up). Retries up to 5 times
    with a 5-second delay between attempts.

step_3_open_modbus:
  description: >
    Opens persistent TCP connections to each inverter defined in config.yaml.
    These connections stay open across polling cycles and are only
    reconnected if they drop.

step_4_publish_discovery:
  description: >
    Publishes MQTT discovery messages for every register on every inverter.
    Each message tells Home Assistant how to create a sensor entity —
    including its name, unique ID, unit, device class, and state topic.
    Messages are retained so HA picks them up even after a restart.

step_5_group_registers:
  description: >
    Pre-sorts all registers by their "group" field from registers.yaml.
    This allows the main loop to read and publish registers in logical
    batches rather than one by one.
```

## Register Groups

```yaml
groups:
  config:
    description: "Static values: serial number, firmware version, SOC limits, grid injection settings"
    examples: [serial_no, firmware_version, on_grid_soc_limit, grid_inject_limit]

  now-base:
    description: "Core real-time values for the energy flow overview"
    examples: [pv, grid_power, battery, battery_soc, inverter, backup, consumption]

  now-grid:
    description: "Detailed grid phase voltages, currents, and frequency"
    examples: [grid_a, grid_b, grid_c, ac_voltage_a, ac_current_a, grid_frequency]

  now-pv:
    description: "PV string-level detail (voltage, current, power per string)"
    examples: [pv_voltage_1, pv_current_1, pv_1, pv_2]

  now-inverter:
    description: "Inverter temperature sensors and per-phase inverter power"
    examples: [inverter_temp1, inverter_temp2, inverter_a, inverter_b, inverter_c]

  now-backup:
    description: "Backup output voltages, currents, frequencies, and power per phase"
    examples: [backup_voltage_a, backup_a, backup_frequency_a]

  now-battery:
    description: "Battery health and cell-level detail"
    examples: [battery_soh, battery_temp, battery_cell_v_max, battery_cell_t_min]

  day:
    description: "Daily energy counters (reset each day)"
    examples: [pv_day, grid_feed_day, grid_purchase_day, battery_charge_day, consumption_day]

  total:
    description: "Lifetime energy counters"
    examples: [pv_total, grid_feed_total, grid_purchase_total, consumption_total]
```

## Main Loop

```yaml
polling_interval: "1 second (drift-compensated using time.monotonic)"

cycle:
  step_1_check_connection:
    description: >
      For each inverter, checks if the persistent Modbus TCP connection
      is still open. If it dropped (inverter reboot, network blip),
      attempts to reconnect.

  step_2_read_registers:
    description: >
      Iterates through each register group. For every real Modbus register
      in the group, reads the raw value from the inverter using
      read_holding_registers(). Decodes the raw bytes according to the
      register's type (U16, I16, I32, U32, STR, DAT, BYTE) and applies
      the scaling factor.

  step_3_calculate_pseudo_registers:
    description: >
      After reading real registers in a group, calculates derived
      pseudo-registers (e.g. household consumption = PV + battery - grid).
      These have no Modbus address — their values come from combining
      other register readings.

  step_4_publish_group:
    description: >
      Publishes all values in the group (both real and pseudo) to MQTT.
      Each register gets its own state topic following the pattern:
      {base_topic}/sensor/{inverter_name}/{mqtt_id}/state.
      Values that are None (failed reads or unimplemented pseudo-registers)
      are skipped.

  step_5_sleep:
    description: >
      Calculates how long the read/publish cycle took and sleeps only
      the remaining time to maintain a consistent 1-second interval.
```

## Data Type Decoding

```yaml
supported_types:
  U16:  "Unsigned 16-bit integer (1 register)"
  I16:  "Signed 16-bit integer (1 register)"
  U32:  "Unsigned 32-bit integer (2 registers, big-endian)"
  I32:  "Signed 32-bit integer (2 registers, big-endian)"
  STR:  "ASCII string across multiple registers"
  BYTE: "Raw byte value (treated as U16)"
  DAT:  "Raw register data passed through as-is"

scaling: >
  If a register defines a scale factor (e.g. scale: 10), the decoded
  integer is divided by that factor. For example, a raw value of 2345
  with scale 10 becomes 234.5.
```

## MQTT Topic Structure

```yaml
discovery_topic: "{base_topic}/sensor/{inverter_name}/{mqtt_id}/config"
state_topic:     "{base_topic}/sensor/{inverter_name}/{mqtt_id}/state"

example:
  base_topic: "homeassistant"
  inverter_name: "inverter_1"
  mqtt_id: "battery_soc"
  resulting_topics:
    discovery: "homeassistant/sensor/inverter_1/battery_soc/config"
    state:     "homeassistant/sensor/inverter_1/battery_soc/state"
```

## Dependencies

```yaml
python_packages:
  - pyModbusTCP    # Modbus TCP client
  - paho-mqtt      # MQTT client
  - PyYAML         # YAML config parsing

standard_library:
  - json
  - socket
  - time
  - os
  - logging
  - collections
```