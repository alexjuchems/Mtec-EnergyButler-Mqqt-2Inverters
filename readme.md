# Mtec-EnergyButler-Mqqt-2Inverters

## Introduction
Welcome to the `Mtec-EnergyButler-Mqqt-2Inverters` project! This project enables you to read data from two M-TEC EnergyButler inverters (https://www.mtec-systems.com) via ModbusTCP and publish it to an MQTT broker for seamless integration with home automation systems like Home Assistant. It’s designed to help you monitor and manage your solar energy system efficiently.

**Highlights**:
- Supports two M-TEC EnergyButler inverters simultaneously.
- No additional hardware or inverter modifications required.
- Runs on any Linux-based system (e.g., Raspberry Pi or Debian server).
- Works within your local network—no internet connection needed.
- Monitors over 80 parameters, including power, voltage, battery status, and more.
- Clustered reading of registers to minimize Modbus traffic.
- Enables frequent data polling (e.g., every second).
- MQTT integration for easy use with Home Assistant, ioBroker, or other platforms.
- Home Assistant auto-discovery via MQTT for automatic sensor setup.
- Automated setup with `autoinstall.sh`, including console-based configuration.

I hope this project enhances your energy management or home automation setup! 😊

### Disclaimer
This is a hobby project inspired by https://github.com/croedel/MTECmqtt created through reverse-engineering, not affiliated with or supported by M-TEC GmbH. Use at your own risk. The author is not responsible for functionality issues or potential damage.

### Credits
This project would not have been possible without the really valuable pre-work of other people, especially:
- https://www.photovoltaikforum.com/thread/206243-erfahrungen-mit-m-tec-energy-butler-hybrid-wechselrichter
- https://forum.iobroker.net/assets/uploads/files/1681811699113-20221125_mtec-energybutler_modbus_rtu_protkoll.pdf
- https://smarthome.exposed/wattsonic-hybrid-inverter-gen3-modbus-rtu-protocol

### Compatibility
Developed for M-TEC EnergyButler inverters (10kW-3P-3G40, 12kW-3P-3G40), this project may also work with other GEN3 models. It might be compatible with similar inverters (e.g., Wattsonic, Sunways, Daxtrom) sharing the same or similar firmware, but this is untested and at your own risk.

## Setup & Configuration
### Prerequisites
- **Hardware**: Two M-TEC EnergyButler inverters with ModbusTCP enabled.
- **Network**: Stable LAN connection to inverters (default port: 502) and an MQTT broker.
- **Software**:
  - Debian-based system (e.g., Raspberry Pi with Debian/Raspbian).
  - Python 3.8 or higher.
  - MQTT broker (e.g., Mosquitto).
  - Git for cloning the repository.

### Installation
The `autoinstall.sh` script is the easiest way to set up the project on a Debian-based system. It prompts for configuration details via the console and installs all the dependencies.
Installs all needed dependencies
creates a config.yaml with all the important information
Set the right permissions for users on the files
Creates sysetemd service for auto start 

1. **Installation of Git**
    ```bash
    sudo apt update
    sudo apt install -y git
    ```
2. **Clone the Repository**
 ```bash
   git clone https://github.com/alexjuchems/Mtec-EnergyButler-Mqqt-2Inverters.git
   cd Mtec-EnergyButler-Mqqt-2Inverters
   ```
  3. **Run the Auto-Install Script**:
   ```bash
   chmod +x autoinstall.sh
   ./autoinstall.sh
   ```
   The script will:
   - Prompt for:
     - MQTT server IP.
     - MQTT username and password 
     - IP addresses for both inverters.
   - Install python3 python3-pip python3-venv mosquitto mosquitto-clients
   - Create a Python virtual environment.
   - Install Python dependencies (`pyyaml`, `pyModbusTCP`, `paho-mqtt`).
   - Generate a `config.yaml` file based on your inputs.
   - Set up a systemd service (`modbus-mqtt`) for automatic operation that depends on the Mosquitto service.
   - Create a placeholder `registers.yaml` if missing.

  4. ***Configuration***
The `autoinstall.sh` script generates `config.yaml`:
The resulting `config.yaml` looks like:
```yaml
mqtt:
  host: "<MQTT_Broker_IP>"      # MQTT server IP
  port: 1883                    # MQTT server port
  username: "<MQTT_Username>"   # MQTT Username
  password: "<MQTT_Password>"   # MQTT Password
  base_topic: "homeassistant"   # MQTT topic name 
inverters:
  inverter1:
    host: "<Inverter1_IP>"  # IP address / hostname of "espressif" modbus server
    port: 502               # Port (IMPORTANT: you need to change this to 5743 for firmware versions older than 27.52.4.0)
    slave: 255              # Modbus slave id (usually no change required)
  inverter2:
    host: "<Inverter2_IP>"
    port: 502
    slave: 255
```
As next step, you need to enable and configure the MQTT integration within Home Assistant. After that, the auto discovery should do it's job and the Inverter sensors should appear on your dashboard.

### Manual Installation (if not using `autoinstall.sh`):

   - Install dependencies:
     ```bash
     sudo apt-get update
     sudo apt-get install -y python3 python3-pip python3-venv git mosquitto mosquitto-clients
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
   - Create `config.yaml`