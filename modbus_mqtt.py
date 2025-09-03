import yaml
import os
import time
from pyModbusTCP.client import ModbusClient
import logging
import paho.mqtt.client as mqtt
import json

# ---------------------------
# Load configuration
# ---------------------------
# Load config from the working directory
with open(os.path.join(os.getcwd(), "config.yaml"), "r") as f:
    config = yaml.safe_load(f)

# Load register definitions from the working directory
with open(os.path.join(os.getcwd(), "registers.yaml"), "r") as f:
    registers = yaml.safe_load(f)

# Logging
#logging.basicConfig()
#logging.getLogger('pyModbusTCP.client').setLevel(logging.DEBUG)

# ---------------------------
# Setup MQTT
# ---------------------------
# MQTT connection with retry logic
mqtt_cfg = config["mqtt"]
client_mqtt = mqtt.Client(client_id="modbus_mqtt", protocol=mqtt.MQTTv5)  # Use MQTTv5 to address deprecation warning
max_retries = 5
retry_delay = 5

if mqtt_cfg.get("username"):
    client_mqtt.username_pw_set(mqtt_cfg["username"], mqtt_cfg["password"])

for attempt in range(max_retries):
    try:
        logging.info(f"Attempting to connect to MQTT broker at {mqtt_cfg['host']}:{mqtt_cfg['port']} (attempt {attempt+1}/{max_retries})")
        client_mqtt.connect(mqtt_cfg["host"], mqtt_cfg["port"], 60)
        logging.info("Successfully connected to MQTT broker")
        break
    except Exception as e:
        logging.error(f"Failed to connect to MQTT broker: {e}")
        if attempt < max_retries - 1:
            logging.info(f"Retrying in {retry_delay} seconds...")
            time.sleep(retry_delay)
        else:
            logging.critical("Max retries reached, exiting")
            raise

client_mqtt.loop_start() # keep MQTT connection alive

# ---------------------------
# Helper function to decode registers
# ---------------------------
def decode_registers(raw, reg_info):
    if not raw:
        return None

    reg_type = reg_info.get("type", "U16")
    scale = reg_info.get("scale", 1)

    if reg_type == "STR":
        value = (
            b"".join(x.to_bytes(2, "big") for x in raw)
            .decode("ascii", errors="ignore")
            .strip()
        )
    elif reg_type == "BYTE" or reg_type == "U16":
        value = raw[0] if len(raw) == 1 else raw
    elif reg_type == "I16":
        value = int.from_bytes(raw[0].to_bytes(2, "big"), byteorder="big", signed=True)
    elif reg_type == "I32":
        if len(raw) >= 2:
            # Treat registers as unsigned 16-bit
            high = raw[0] & 0xFFFF
            low = raw[1] & 0xFFFF

            # Combine into 32-bit integer (big-endian: high word first)
            value = (high << 16) | low

            # Convert to signed
            if value >= 0x80000000:
                value -= 0x100000000
        else:
            value = None
    elif reg_type == "U32":
        if len(raw) >= 2:
            # Treat registers as unsigned 16-bit
            high = raw[0] & 0xFFFF
            low = raw[1] & 0xFFFF

            # Combine into 32-bit unsigned integer (big-endian)
            value = (high << 16) | low
        else:
            value = None
    elif reg_type == "DAT":
        value = raw
    else:
        value = raw

    if isinstance(value, (int, float)) and scale != 1:
        return value / scale
    return value

# ---------------------------
# Publish MQTT Discovery configs
# ---------------------------
def publish_discovery(inv_name, reg_id, reg_info):
    object_id = reg_info.get("mqtt", reg_id)
    state_topic = f"{mqtt_cfg['base_topic']}/sensor/{inv_name}/{object_id}/state"

    payload = {
        "name": f"{inv_name} {reg_info.get('name','Unknown')}",
        "state_topic": state_topic,
        "unique_id": f"{inv_name}_{object_id}",
        "device": {
            "identifiers": [inv_name],
            "name": inv_name,
            "manufacturer": "MySolar",
            "model": "Modbus Inverter",
        },
    }

    if "unit" in reg_info:
        payload["unit_of_measurement"] = reg_info["unit"]
    if "hass_device_class" in reg_info:
        payload["device_class"] = reg_info["hass_device_class"]
    if "hass_state_class" in reg_info:
        payload["state_class"] = reg_info["hass_state_class"]
    if "hass_value_template" in reg_info:
        payload["value_template"] = reg_info["hass_value_template"]

    discovery_topic = f"{mqtt_cfg['base_topic']}/sensor/{inv_name}/{object_id}/config"
    client_mqtt.publish(discovery_topic, json.dumps(payload), retain=True)

# ---------------------------
# Setup discovery once
# ---------------------------
for inv_name, inv in config["inverters"].items():
    for reg_id, reg_info in registers.items():
            publish_discovery(inv_name, reg_id, reg_info)

print("✅ MQTT discovery messages published. Check Home Assistant → Devices → MQTT")

# ---------------------------
# Main loop: read and publish values
# ---------------------------

while True:
    for inv_name, inv in config["inverters"].items():
        client = ModbusClient(inv["host"], port=inv["port"], timeout=5, unit_id=inv["slave"])
        if client.open():
            for reg_id, reg_info in registers.items():
                length = reg_info.get("length")

                if length:
                    # Real Modbus register
                    reg_address = int(reg_id)
                    raw = client.read_holding_registers(reg_address, length)
                    value = decode_registers(raw, reg_info)
                else:
                    # Pseudo-register → calculate or use placeholder
                    # Example placeholder:
                    value = None  # or some computed value

                # Publish the value to MQTT regardless of real/pseudo
                object_id = reg_info.get("mqtt", reg_id)
                state_topic = f"{mqtt_cfg['base_topic']}/sensor/{inv_name}/{object_id}/state"
                client_mqtt.publish(state_topic, str(value))

            client.close()
        else:
            print(f"❌ Failed to connect to {inv_name}")

    time.sleep(1)