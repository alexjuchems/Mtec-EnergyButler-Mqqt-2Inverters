# M-TEC EnergyButler MQTT for Two Inverters

## Introduction
Welcome to the `Mtec-EnergyButler-Mqqt-2Inverters` project! This project enables you to read data from two M-TEC EnergyButler inverters (https://www.mtec-systems.com) via ModbusTCP and publish it to an MQTT broker for seamless integration with home automation systems like Home Assistant. It’s designed to help you monitor and manage your solar energy system efficiently.

**Highlights**:
- Supports two M-TEC EnergyButler inverters simultaneously.
- No additional hardware or inverter modifications required.
- Runs on any Linux-based system (e.g., Raspberry Pi or NAS server).
- Works within your local network—no internet connection needed.
- Monitors over 50 parameters, including power, voltage, battery status, and more.
- Clustered reading of registers to minimize Modbus traffic.
- Enables frequent data polling (e.g., every second).
- MQTT integration for easy use with Home Assistant, ioBroker, or other platforms.
- Home Assistant auto-discovery via MQTT for automatic sensor setup.
- Automated setup with `autoinstall.sh`, including console-based configuration.

I hope this project enhances your energy management or home automation setup! 😊

### Disclaimer
This is a hobby project created through reverse-engineering, not affiliated with or supported by M-TEC GmbH. Use at your own risk. The author is not responsible for functionality issues or potential damage.

### Compatibility
Developed for M-TEC EnergyButler inverters (e.g., 8kW-3P-3G25), this project may also work with other GEN3 models (https://www.mtec-systems.com/batteriespeicher/energy-butler-11-bis-30-kwh/). It might be compatible with similar inverters (e.g., Wattsonic, Sunways, Daxtrom) sharing the same or similar firmware, but this is untested and at your own risk.

| Provider   | Link                                   |
|------------|----------------------------------------|
| Wattsonic  | https://www.wattsonic.com/             |
| Sunways    | https://de.sunways-tech.com            |
| Daxtromn   | https://daxtromn-power.com/products/   |

### Credits
This project builds on community efforts and open-source tools:
- Photovoltaikforum discussions: https://www.photovoltaikforum.com
- Modbus protocol references for M-TEC and similar inverters.
- Open-source libraries: `pyModbusTCP`, `paho-mqtt`, `pyyaml`.

## Setup & Configuration
### Prerequisites
- **Hardware**: Two M-TEC EnergyButler inverters with ModbusTCP enabled.
- **Network**: Stable LAN connection to inverters (default port: 502) and an MQTT broker.
- **Software**:
  - Debian-based system (e.g., Raspberry Pi with Debian/Raspbian).
  - Python 3.8 or higher.
  - MQTT broker (e.g., Mosquitto). Install it with:
    ```bash
    sudo apt install mosquitto mosquitto-clients
    ```
  - Git for cloning the repository.

### Installation
The `autoinstall.sh` script is the easiest way to set up the project on a Debian-based system. It prompts for configuration details via the console and installs everything automatically.

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/alexjuchems/Mtec-EnergyButler-Mqqt-2Inverters.git
   cd Mtec-EnergyButler-Mqqt-2Inverters
   ```

2. **Run the Auto-Install Script**:
   ```bash
   chmod +x autoinstall.sh
   ./autoinstall.sh
   ```

   The script will:
   - Prompt for:
     - MQTT server IP (e.g., `192.168.178.180`).
     - MQTT username and password (if required).
     - IP addresses for both inverters (e.g., `192.168.178.163`, `192.168.178.199`).
   - Install system dependencies (`python3`, `python3-pip`, `python3-venv`, `git`).
   - Create a Python virtual environment.
   - Install Python dependencies (`pyyaml`, `pyModbusTCP`, `paho-mqtt`).
   - Generate a `config.yaml` file based on your inputs.
   - Set up a systemd service (`modbus-mqtt`) for automatic operation.
   - Create a placeholder `registers.yaml` if missing.

3. **Manual Installation** (if not using `autoinstall.sh`):
   - Install dependencies:
     ```bash
     sudo apt-get update
     sudo apt-get install -y python3 python3-pip python3-venv git
     ```
   - Set up a virtual environment:
     ```bash
     python3 -m venv venv
     source venv/bin/activate
     ```
   - Install Python packages:
     ```bash
     pip install pyyaml pyModbusTCP paho-mqtt
     ```
   - Create `config.yaml` (see **Configuration** below).

### Configuration
The `autoinstall.sh` script generates `config.yaml` by prompting for:
- **MQTT Server**: IP, username, and password.
- **Inverter IPs**: IP addresses for both inverters.

The resulting `config.yaml` looks like:
```yaml
mqtt:
  host: "<MQTT_Broker_IP>"
  port: 1883
  username: "<MQTT_Username>"
  password: "<MQTT_Password>"
  base_topic: "homeassistant"
inverters:
  inverter1:
    host: "<Inverter1_IP>"
    port: 502
    slave: 255
  inverter2:
    host: "<Inverter2_IP>"
    port: 502
    slave: 255
```

#### Manual Configuration
If you skip `autoinstall.sh`, manually create `config.yaml` in the repository directory with the above structure. Replace placeholders with your MQTT and inverter details.

#### Additional Notes
- **Modbus Port**: Default is 502. If your inverters use firmware V27.52.4.0 or newer, set `port: 5743` in `config.yaml`.
- **Registers**: The `registers.yaml` file defines Modbus registers and pseudo-registers (e.g., household consumption). Verify it matches your inverter’s register map. Adjust if needed for non-M-TEC inverters.
- **Permissions**: The `autoinstall.sh` script sets permissions (`config.yaml`: 600, `registers.yaml`: 644, `modbus_mqtt.py`: 755). For manual setup:
  ```bash
  chmod 600 config.yaml
  chmod 644 registers.yaml
  chmod 755 modbus_mqtt.py
  ```

### Home Assistant Support
The script supports Home Assistant MQTT auto-discovery, automatically creating sensors for inverter parameters (e.g., grid power, battery SOC). To enable:
1. Ensure `base_topic` in `config.yaml` matches your Home Assistant MQTT configuration (default: `homeassistant`).
2. Enable the MQTT integration in Home Assistant.
3. Sensors will appear under the MQTT integration after running the script.

## Usage
### Running the Script
- **Manually**:
  ```bash
  source venv/bin/activate
  python modbus_mqtt.py
  ```
  The script connects to both inverters, reads registers from `registers.yaml`, and publishes data to the MQTT broker. Press `Ctrl+C` to stop.

- **As a Systemd Service** (set up by `autoinstall.sh`):
  - Check status:
    ```bash
    sudo systemctl status modbus-mqtt
    ```
  - View logs:
    ```bash
    journalctl -u modbus-mqtt -f
    ```
  - Stop or restart:
    ```bash
    sudo systemctl stop modbus-mqtt
    sudo systemctl restart modbus-mqtt
    ```

### Data Format Written to MQTT
Data is published to MQTT topics under the `base_topic` (e.g., `homeassistant/sensor/inverter1/<parameter>/state`). Topics are grouped by data type, with refresh frequencies determined by the script’s polling loop (every 1 second).

| Group         | Description                     | Example Parameters                     |
|---------------|---------------------------------|----------------------------------------|
| `config`      | Static inverter data            | `serial_no`, `firmware_version`        |
| `now-base`    | Real-time core metrics          | `grid_power`, `battery_soc`, `pv`      |
| `now-grid`    | Grid-related metrics            | `grid_a`, `ac_voltage_a`, `grid_frequency` |
| `now-inverter`| Inverter-specific metrics       | `inverter_temp1`, `inverter_a`         |
| `now-backup`  | Backup power metrics            | `backup_voltage_a`, `backup_a`         |
| `now-battery` | Battery-specific metrics        | `battery_soh`, `battery_temp`          |
| `now-pv`      | PV generation metrics           | `pv_voltage_1`, `pv_1`                 |
| `day`         | Daily statistics                | `grid_feed_day`, `pv_day`, `consumption_day` (*) |
| `total`       | Lifetime statistics             | `grid_feed_total`, `pv_total`, `consumption_total` (*) |

*Note*: Parameters marked with (*) are calculated pseudo-registers.

#### Example Parameters
| Register | MQTT Parameter         | Unit | Description                          |
|----------|------------------------|------|--------------------------------------|
| 10000    | `serial_no`            |      | Inverter serial number               |
| 11000    | `grid_power`           | W    | Grid power                           |
| 33000    | `battery_soc`          | %    | Battery state of charge              |
| 31005    | `pv_day`               | kWh  | PV energy generated (day)            |
| -        | `consumption`          | W    | Household consumption (calculated)   |

See `registers.yaml` for the full list, including data types, scaling factors, and Home Assistant configurations.

## Troubleshooting
- **Inverter Connection Issues**:
  - Verify IP addresses and ports (502 or 5743) with `ping <Inverter_IP>` or a Modbus client.
  - Ensure ModbusTCP is enabled on the inverters.
- **MQTT Issues**:
  - Test broker connectivity: `mosquitto_sub -h <MQTT_IP> -t "test/topic"`.
  - Verify `config.yaml` credentials and `base_topic`.
- **Home Assistant Sensors Missing**:
  - Check MQTT integration and `base_topic` alignment.
  - Inspect discovery messages: `mosquitto_sub -h <MQTT_IP> -t "homeassistant/#"`.
- **Systemd Service Issues**:
  - View logs: `journalctl -u modbus-mqtt -f`.
  - Check file permissions (see **Configuration**).
- **Incorrect Data**:
  - Ensure `registers.yaml` matches your inverter’s Modbus register map.
  - Check for `None` values, indicating invalid registers or connection issues.

## Contributing
Contributions are welcome! To contribute:
1. Fork the repository.
2. Create a feature branch: `git checkout -b feature/YourFeature`.
3. Commit changes: `git commit -m "Add YourFeature"`.
4. Push: `git push origin feature/YourFeature`.
5. Open a pull request with a clear description and tested changes.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments
- Thanks to the open-source community for `pyModbusTCP`, `paho-mqtt`, and `pyyaml`.
- Inspired by reverse-engineering efforts in the Photovoltaikforum and other communities.
- Built for M-TEC EnergyButler but potentially adaptable for Wattsonic, Sunways, or Daxtrom inverters.