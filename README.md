# Robot UDP/TCP Controller (Flutter)

A simple Flutter application for Android designed to remotely control a robot (e.g., a ROS 2-based system) over a local network. It features a joystick for sending velocity commands and displays real-time odometry feedback.

## Features

  * 🕹️ **Joystick Control:** Sends `cmd_vel` (linear X and angular Z) commands at 10Hz.
  * 📊 **Real-time Feedback:** Receives and displays `real_vel` (odometry) data from the robot.
  * 📡 **TCP/UDP Protocol:** Uses TCP for an initial registration (handshake) and UDP for low-latency, real-time data exchange.
  * ⚙️ **Configurable Settings:** Save your server's IP address and port configuration locally.
  * 📱 **Immersive UI:** Runs in full-screen mode to maximize space for controls.
  * 🟢 **Connection Status:** A simple indicator shows if the app is successfully registered with the server.

-----

## 🚀 Getting Started

### Prerequisites

  * [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
  * An Android device or emulator.
  * A server (e.g., a Python script on a ROS 2 machine) running on the same local network.

### Installation & Running

1.  **Clone the repository:**

    ```bash
    git clone https://your-repo-url/robot_controller_app.git
    cd robot_controller_app
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
2.  Tap the **settings icon** (⚙️) in the top-right corner.
3.  Enter your server's details:
      * **Server IP:** The **LAN IP address** of the machine running your server (e.g., `192.168.1.10`).
        > **Important:** Do not use `127.0.0.1` or `localhost` unless you are running the server *on the phone itself*.
      * **TCP Control Port:** The port your server is *listening* on for the initial TCP handshake (e.g., `5001`).
      * **Client ID:** A unique name for this controller (e.g., `robot_1`).
      * **Client UDP Listen Port:** The port this app will use to *receive* odometry data (e.g., `6006`).
4.  Tap "Save and Reconnect". The app will save these settings and attempt to register with the server.

-----

## 🔌 Communication Protocol (How it Works)

This app is only a **client**. It requires a server that follows a specific two-step protocol.

### Step 1: TCP Registration (Handshake)

1.  The Flutter app connects to the server at `SERVER_IP:TCP_CONTROL_PORT`.
2.  The app sends a JSON message to register itself:
    ```json
    {
      "type": "register",
      "client_id": "robot_1",
      "recv_udp_port": 6006
    }
    ```
3.  The server receives this, registers the client, and replies with a JSON message confirming success and providing the server's own UDP port for data:
    ```json
    {
      "ok": true,
      "udp_data_port": 5005 
    }
    ```
    *This `udp_data_port` (e.g., `5005`) is where the app will send its joystick commands.*

### Step 2: UDP Data Exchange (Real-time)

Once registered, all communication becomes UDP.

  * **Client → Server (Joystick Commands):**
    The app sends `cmd_vel` messages at 10Hz to the `udp_data_port` provided by the server.

      * **Destination:** `SERVER_IP:5005`
      * **Payload:**
        ```json
        {
          "client_id": "robot_1",
          "type": "cmd_vel",
          "linear_x": 0.5,
          "angular_z": 0.1
        }
        ```

  * **Server → Client (Odometry Data):**
    The server sends `real_vel` messages back to the app. The server already knows the client's IP (from the TCP connection) and its listening port (from the `recv_udp_port` in the handshake).

      * **Destination:** `CLIENT_IP:6006`
      * **Payload:**
        ```json
        {
          "type": "real_vel",
          "linear_x": 0.49,
          "angular_z": 0.09
        }
        ```

-----

## 🛠️ Key Dependencies

  * **[flutter\_joystick](https://pub.dev/packages/flutter_joystick):** For the joystick UI.
  * **[provider](https://pub.dev/packages/provider):** For state management (connection status, odometry).
  * **[shared\_preferences](https://pub.dev/packages/shared_preferences):** For saving and loading the server configuration.
  * **[udp](https://www.google.com/search?q=https://pub.dev/packages/udp):** For all UDP send/receive operations.
  * **[dart:io](https://www.google.com/search?q=https://api.dart.dev/stable/2.19.6/dart-io/dart-io-library.html):** Used for the initial TCP `Socket` connection.