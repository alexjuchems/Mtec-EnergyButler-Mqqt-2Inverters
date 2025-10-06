#!/bin/bash

# Script to auto-setup a Modbus-to-MQTT script on Debian after cloning the repository

# Configuration
INSTALL_DIR="$(pwd)"  # Use current directory (cloned repository)
SCRIPT_NAME="modbus_mqtt.py"
SERVICE_NAME="modbus-mqtt"
VENV_DIR="$INSTALL_DIR/venv"

# Exit on any error
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate IP address format
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        for octet in $(echo "$ip" | tr '.' ' '); do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Prompt for MQTT server details
echo "Enter MQTT server details:"
while true; do
    read -p "MQTT Server IP (e.g., 192.168.178.180): " MQTT_IP
    if validate_ip "$MQTT_IP"; then
        break
    else
        echo "Error: Invalid IP address format. Please try again."
    fi
done
read -p "MQTT Username: " MQTT_USERNAME
while true; do
    read -sp "MQTT Password: " MQTT_PASSWORD
    echo
    read -sp "Confirm MQTT Password: " MQTT_PASSWORD_CONFIRM
    echo
    if [ "$MQTT_PASSWORD" = "$MQTT_PASSWORD_CONFIRM" ]; then
        break
    else
        echo "Error: Passwords do not match. Please try again."
    fi
done

# Prompt for inverter IP addresses
echo "Enter Modbus-TCP server details:"
while true; do
    read -p "Inverter 1 IP (e.g., 192.168.178.163): " INVERTER1_IP
    if validate_ip "$INVERTER1_IP"; then
        break
    else
        echo "Error: Invalid IP address format. Please try again."
    fi
done
while true; do
    read -p "Inverter 2 IP (e.g., 192.168.178.199): " INVERTER2_IP
    if validate_ip "$INVERTER2_IP"; then
        break
    else
        echo "Error: Invalid IP address format. Please try again."
    fi
done

# Install system dependencies
echo "Installing system dependencies..."
if ! sudo apt-get update; then
    echo "Error: Failed to update package list."
    exit 1
fi
if ! sudo apt-get install -y python3 python3-pip python3-venv mosquitto mosquitto-clients; then
    echo "Error: Failed to install system dependencies."
    exit 1
fi

# Ensure installation directory is writable
echo "Ensuring $INSTALL_DIR is writable..."
sudo chown "$USER:$USER" "$INSTALL_DIR"

# Verify required files in the current directory
for file in "$SCRIPT_NAME" "registers.yaml"; do
    if [ ! -f "$INSTALL_DIR/$file" ]; then
        if [ "$file" = "registers.yaml" ]; then
            echo "Warning: $file not found in $INSTALL_DIR. Creating a placeholder..."
            cat << EOF > "$INSTALL_DIR/registers.yaml"
# Example register definitions (replace with actual inverter register map)
example_register:
  name: "Example Register"
  type: "U16"
  length: 1
  mqtt: "example"
  unit: ""
EOF
        else
            echo "Error: Required file $file not found in $INSTALL_DIR"
            exit 1
        fi
    fi
done

# Set up virtual environment
echo "Setting up Python virtual environment..."
if ! python3 -m venv "$VENV_DIR"; then
    echo "Error: Failed to create virtual environment."
    exit 1
fi
source "$VENV_DIR/bin/activate"

# Install Python dependencies
echo "Installing Python dependencies..."
if ! "$VENV_DIR/bin/pip" install pyyaml pyModbusTCP paho-mqtt; then
    echo "Error: Failed to install Python dependencies."
    exit 1
fi

# Create or overwrite config.yaml with user-provided configuration
echo "Creating config.yaml..."
cat << EOF > "$INSTALL_DIR/config.yaml"
mqtt:
  host: "$MQTT_IP"
  port: 1883
  username: "$MQTT_USERNAME"
  password: "$MQTT_PASSWORD"
  base_topic: "homeassistant"
inverters:
  inverter1:
    host: "$INVERTER1_IP"
    port: 502
    slave: 255
  inverter2:
    host: "$INVERTER2_IP"
    port: 502
    slave: 255
EOF
sudo chmod 600 "$INSTALL_DIR/config.yaml"  # Restrict permissions for sensitive data
sudo chmod 644 "$INSTALL_DIR/registers.yaml"
sudo chmod 755 "$INSTALL_DIR/$SCRIPT_NAME"

# Create a systemd service file
echo "Setting up systemd service..."
CURRENT_USER=$(whoami)
cat << EOF | sudo tee /etc/systemd/system/$SERVICE_NAME.service
[Unit]
Description=Modbus to MQTT Service
After=network-online.target mosquitto.service
Requires=mosquitto.service network-online.target

[Service]
ExecStartPre=/bin/sleep 5
WorkingDirectory=$INSTALL_DIR
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable, and start the service
if ! sudo systemctl daemon-reload; then
    echo "Error: Failed to reload systemd."
    exit 1
fi
if ! sudo systemctl enable "$SERVICE_NAME"; then
    echo "Error: Failed to enable systemd service."
    exit 1
fi
if ! sudo systemctl start "$SERVICE_NAME"; then
    echo "Error: Failed to start systemd service."
    exit 1
fi

# Check service status
echo "Checking service status..."
sudo systemctl status "$SERVICE_NAME" --no-pager

echo "Installation complete! The Modbus-to-MQTT script is running as a systemd service."
echo "Check the service status with: sudo systemctl status $SERVICE_NAME"
echo "Logs can be viewed with: journalctl -u $SERVICE_NAME -f"
echo "Verify $INSTALL_DIR/registers.yaml matches your inverter's register definitions."
