# Robot UDP/TCP Controller (Flutter)

A Flutter application for Android designed to remotely control a robot (e.g., a ROS 2-based system) over a local network. It features a joystick for velocity control, displays real-time odometry and power usage, renders an occupancy grid map, and streams live video from the robot.

## Features

*   🕹️ **Joystick Control:** Sends `cmd_vel` (linear X and angular Z) commands at 10Hz.
*   🎥 **Video Streaming:** Low-latency H.264 video streaming via UDP (port 5004).
*   �️ **Occupancy Grid Map:** Renders a real-time obstacle map received from the robot.
*   📊 **Real-time Telemetry:** Displays odometry speed, battery level, motor power, and Jetson power usage.
*   🗑️ **Interactive Pickup System:** Receives "trash detected" alerts and handles "pickup" requests/responses.
*   📡 **TCP/UDP Protocol:** TCP for robust control (start/stop/mode) and handshake; UDP for high-frequency data (video, map, odometry).
*   ⚙️ **Configurable Settings:** Save server IP, ports, and client ID.
*   🎨 **Customizable HUD:** Move and scale UI elements (joysticks, map, data display) to suit your preference.
*   � **Mode Switching:** Toggle between Manual, Auto, and Calibration modes.

-----

## 🚀 Getting Started

### Prerequisites

*   [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
*   An Android device.
*   A robot running the compatible server (ROS 2 node) on the same local network.

### Installation & Running

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/Cassian-5SIEC/controller_app.git
    cd controller_app
    ```

2.  **Install dependencies:**

    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    Connect an Android device via USB (with debugging enabled).

    ```bash
    flutter run
    ```

-----

## 🔧 Configuration

Before the app can connect, you **must** configure it to point to your server.

1.  Start the app.
2.  Tap the **settings icon** (⚙️) in the top-left corner.
3.  Enter your server's details:
      * **Server IP:** The **LAN IP address** of the machine running your server (e.g., `192.168.1.10`).
      * **TCP Control Port:** The port your server is *listening* on for the initial handshake and control commands (e.g., `5001`).
      * **Client ID:** A unique name for this controller (e.g., `robot_1`).
      * **Client UDP Listen Port:** The port this app will use to *receive* data (e.g., `6006`).
4.  The **Video Port** is currently fixed to `5004` in the code unless modified.
5.  Tap "Save and Reconnect".

-----

## 🔌 Communication Protocol

The system uses a hybrid TCP/UDP protocol.

### Step 1: TCP Registration (Handshake)

1.  **Connect:** App connects to `SERVER_IP:TCP_CONTROL_PORT`.
2.  **Register:** App sends:
    ```json
    {
      "type": "register",
      "client_id": "robot_1",
      "recv_udp_port": 6006,
      "recv_image_port": 5004
    }
    ```
3.  **Acknowledge:** Server replies:
    ```json
    {
      "ok": true,
      "udp_data_port": 5005
    }
    ```

### Step 2: Protocol Messages

#### TCP (Control & Reliable Events)

**Client → Server:**
*   `{"type": "start", "client_id": "..."}` - Start operation.
*   `{"type": "emergency_stop", "client_id": "..."}` - Immediate stop.
*   `{"type": "set_mode", "mode": 0/1/2, ...}` - 0: Manual, 1: Auto, 2: Calibration.
*   `{"type": "response-pickup", "response": true/false}` - User accepted/rejected pickup.
*   `{"type": "heartbeat_ack"}` - Reply to server heartbeat.

**Server → Client:**
*   `{"type": "cmd", "cmd": "start"/"stop"}` - Remote start/stop confirmation.
*   `{"type": "cmd", "cmd": "set_mode", "mode": 0/1/2}` - Mode update confirmation.
*   `{"type": "ask-pickup"}` - Triggers a popup asking user to confirm pickup.
*   `{"type": "trash-detected"}` - Notification that a target was found.
*   `{"type": "heartbeat"}` - Keep-alive check.

#### UDP (High-Frequency Data)

**Client → Server (Target: `udp_data_port`):**
*   **Velocity Command (10Hz):**
    ```json
    {
      "type": "cmd_vel",
      "linear_x": 0.5,
      "angular_z": 0.1
    }
    ```

**Server → Client (Target: `recv_udp_port`):**
*   **Odometry:** `{"type": "real_vel", "linear_x": ..., "angular_z": ...}`
*   **General Data:** `{"type": "general_data", "battery_level": %, "battery_power": W, "left_motor_power": W, "right_motor_power": W, "jetson_power": W}`
*   **Map:** `{"type": "occupancy_grid", "width": W, "height": H, "data": [0, 100, -1...], "resolution": R, "car_yaw": Y}`

**Server → Client (Target: `recv_image_port` / 5004):**
*   **Video:** Raw H.264 RTP stream.

-----

## 🛠️ Key Dependencies

*   **flutter_joystick:** UI controls.
*   **provider:** State management.
*   **udp:** Datagram sockets.
*   **flutter_gstreamer_player:** Low-latency video decoding.
*   **toggle_switch:** Mode selection.