# Mtec-EnergyButler-Mqqt-2Inverters

This project provides a Python script to read data from two M-TEC EnergyButler inverters (or compatible systems like Wattsonic, Sunways, Daxtrom) via ModbusTCP and publish the data to an MQTT broker for integration with home automation systems like Home Assistant. The script supports a wide range of inverter parameters, including power, voltage, current, and battery status, as defined in the `registers.yaml` file.

## Features
- Reads data from two M-TEC EnergyButler inverters using ModbusTCP.
- Publishes inverter data to an MQTT broker for real-time monitoring.
- Supports Home Assistant MQTT discovery for automatic sensor creation.
- Includes an `autoinstall.sh` script that prompts for configuration details via the console and sets up a systemd service on Debian-based systems.
- Extensive register definitions in `registers.yaml` for inverter parameters, including calculated pseudo-registers.

## Prerequisites
- **Hardware**:
  - Two M-TEC EnergyButler inverters (or compatible models) with ModbusTCP enabled.
  - Network access to the inverters (default port: 502).
- **Software**:
  - Debian-based system (e.g., Raspberry Pi with Debian/Raspbian).
  - Python 3.8 or higher.
  - MQTT broker (e.g., Mosquitto) running and accessible.
  - Git for cloning the repository.
- **Network**:
  - Stable network connection to both inverters and the MQTT broker.

## Installation
### Automated Installation (Recommended)
The `autoinstall.sh` script automates the setup process on Debian-based systems, including prompting for configuration details via the console.

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
   - Prompt for MQTT server details (IP, username, password) and inverter IP addresses via the console.
   - Install system dependencies (`python3`, `python3-pip`, `python3-venv`, `git`).
   - Create a Python virtual environment.
   - Install Python dependencies (`pyyaml`, `pyModbusTCP`, `paho-mqtt`).
   - Generate a `config.yaml` file based on your console inputs.
   - Set up a systemd service (`modbus-mqtt`) to run the script automatically.
   - Create a placeholder `registers.yaml` if it’s missing.

### Manual Installation
If you prefer manual setup or are not using a Debian-based system:
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/alexjuchems/Mtec-EnergyButler-Mqqt-2Inverters.git
   cd Mtec-EnergyButler-Mqqt-2Inverters
   ```

2. **Install System Dependencies**:
   ```bash
   sudo apt-get update
   sudo apt-get install -y python3 python3-pip python3-venv git
   ```

3. **Set Up Python Virtual Environment**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

4. **Install Python Dependencies**:
   ```bash
   pip install pyyaml pyModbusTCP paho-mqtt
   ```

5. **Create `config.yaml`**:
   Manually create a `config.yaml` file in the repository directory with the following structure:
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
   Replace `<MQTT_Broker_IP>`, `<MQTT_Username>`, `<MQTT_Password>`, `<Inverter1_IP>`, and `<Inverter2_IP>` with your specific values.

## Configuration
The `autoinstall.sh` script simplifies configuration by prompting for the following details via the console:
- **MQTT Server IP** (e.g., `192.168.178.180`): The IP address of your MQTT broker.
- **MQTT Username and Password**: Credentials for the MQTT broker (if required).
- **Inverter 1 and 2 IPs** (e.g., `192.168.178.163`, `192.168.178.199`): The IP addresses of your two inverters.

These inputs are used to generate the `config.yaml` file automatically. The generated file looks like:
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

### Additional Configuration
- **Verify `registers.yaml`**:
  The `registers.yaml` file defines the Modbus registers to read from the inverters. It includes:
  - Real Modbus registers (e.g., inverter status, grid power, battery SOC).
  - Calculated pseudo-registers (e.g., household consumption, autarky rate).
  - Home Assistant MQTT discovery configurations for automatic sensor creation.
  Ensure the register definitions match your inverter’s Modbus register map. The provided `registers.yaml` includes a comprehensive set of parameters but may need adjustments for specific inverter models.
- **Modbus Port**: The default port is 502. Some inverter firmware versions may use port 5743. If connection issues occur, update the `port` field in `config.yaml` for each inverter.
- **File Permissions**: The `autoinstall.sh` script sets appropriate permissions (`config.yaml`: 600, `registers.yaml`: 644, `modbus_mqtt.py`: 755). If installing manually, ensure these permissions are applied:
  ```bash
  chmod 600 config.yaml
  chmod 644 registers.yaml
  chmod 755 modbus_mqtt.py
  ```

## Usage
1. **Run the Script Manually**:
   ```bash
   source venv/bin/activate
   python modbus_mqtt.py
   ```
   The script will:
   - Connect to both inverters via ModbusTCP.
   - Read registers defined in `registers.yaml`.
   - Publish data to the MQTT broker under the specified `base_topic` (e.g., `homeassistant/sensor/inverter1/<register>/state`).
   - Publish Home Assistant MQTT discovery messages for automatic sensor setup.

2. **Run as a Systemd Service** (if using `autoinstall.sh`):
   - The service is automatically set up and started by `autoinstall.sh`.
   - Check the service status:
     ```bash
     sudo systemctl status modbus-mqtt
     ```
   - View logs:
     ```bash
     journalctl -u modbus-mqtt -f
     ```
   - Stop or restart the service if needed:
     ```bash
     sudo systemctl stop modbus-mqtt
     sudo systemctl restart modbus-mqtt
     ```

3. **Integrate with Home Assistant**:
   - Ensure the MQTT integration is enabled in Home Assistant.
   - The script publishes MQTT discovery messages, so sensors for each inverter parameter (e.g., grid power, battery SOC) should automatically appear in Home Assistant under the MQTT integration.
   - Verify the `base_topic` in `config.yaml` matches your Home Assistant MQTT configuration.

## Register Definitions
The `registers.yaml` file includes:
- **Modbus Registers**: Parameters like inverter serial number, grid power, battery voltage, and PV generation, with details such as register address, data type (e.g., `U16`, `I32`, `STR`), unit, and scaling factor.
- **Pseudo-Registers**: Calculated values like household consumption and autarky rate.
- **Home Assistant Integration**: Each register includes MQTT topic names and Home Assistant-specific fields (e.g., `hass_device_class`, `hass_value_template`) for seamless integration.

Example register:
```yaml
"11000":
  name: Grid power
  length: 2
  type: I32
  unit: W
  mqtt: grid_power
  group: now-base
  hass_device_class: power
  hass_value_template: "{{ value | round(0) }}"
  hass_state_class: measurement
```

## Troubleshooting
- **Connection Issues**:
  - Verify inverter IP addresses and ports (502 or 5743) using `ping <Inverter_IP>` or a Modbus client.
  - Ensure the inverters have ModbusTCP enabled.
- **MQTT Issues**:
  - Confirm the MQTT broker is running and accessible (`mosquitto_sub -h <MQTT_IP> -t "test/topic"`).
  - Check `config.yaml` for correct MQTT credentials and topic settings.
- **Missing Sensors in Home Assistant**:
  - Ensure the MQTT integration is configured and the `base_topic` matches.
  - Check MQTT discovery messages using an MQTT client (e.g., `mosquitto_sub -h <MQTT_IP> -t "homeassistant/#"`).
- **Service Issues**:
  - Check logs: `journalctl -u modbus-mqtt -f`.
  - Verify file permissions: `config.yaml` (600), `registers.yaml` (644), `modbus_mqtt.py` (755).
- **Register Errors**:
  - Ensure `registers.yaml` matches your inverter’s Modbus register map. Incorrect addresses or types may cause data to be `None`.

## Contributing
Contributions are welcome! To contribute:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/YourFeature`).
3. Commit your changes (`git commit -m "Add YourFeature"`).
4. Push to the branch (`git push origin feature/YourFeature`).
5. Open a pull request.

Please include clear descriptions of changes and test your modifications with your inverter setup.

## Acknowledgments
- Built for M-TEC EnergyButler inverters but may work with similar systems (e.g., Wattsonic, Sunways, Daxtrom) with register adjustments.
- Thanks to the open-source community for libraries like `pyModbusTCP`, `paho-mqtt`, and `pyyaml`.
- Inspired by reverse-engineering efforts for Modbus-based inverters.
