# Network HMI Client Integration Guide

This document describes how to implement a client to interact with the `network_hmi` system, specifically focusing on the new TCP video streaming capability.

## Overview

The communication consists of three parts:
1.  **TCP Control Channel**: For commands, status, and handshake.
2.  **UDP Data Channel**: For telemetry (speed, battery, map) sent from Robot to Client.
3.  **TCP Video Channel**: For H.264 video streaming from Robot to Client.

## 1. Connection Handshake (Control Channel)

The client must first connect to the Robot's **TCP Control Port** (default: `5001`).

### Registration
Once connected, the client must send a registration JSON message.

**Request:**
```json
{
  "type": "register",
  "client_id": "unique_client_name",
  "recv_udp_port": 1234,      // The UDP port where YOUR Client listens for telemetry
  "recv_image_port": 0        // (Legacy) Set to 0 or any value, ignored for TCP video
}
```

**Response:**
The server will reply with a JSON message containing the port mapping.

```json
{
  "ok": true,
  "udp_data_port": 5000,      // Port on Robot sending UDP data
  "tcp_video_port": 5002      // NEW: Port on Robot waiting for TCP video connection
}
```

> [!IMPORTANT]
> You must parse `tcp_video_port` from this response to know where to connect for the video stream.

## 2. Video Stream (TCP)

After receiving the `tcp_video_port` (e.g., 5002), the client should establish a **new TCP connection** to the Robot's IP address on that port.

**Protocol Details:**
-   **Transport**: TCP
-   **Protocol**: RTP over TCP (GStreamer `rtpstreampay` / RFC 4571 style framing)
-   **Frame Format**: H.264 (I420 Color Space)
-   **Latency Optimization**: The server is configured for low-latency streaming (`zerolatency`, `ultrafast`).

### Example Client Implementation (GStreamer)

If you are using GStreamer on the client side, you can use the `tcpclientsrc` element.

**Command Line Example:**
```bash
gst-launch-1.0 -v tcpclientsrc host=<ROBOT_IP> port=<TCP_VIDEO_PORT> ! "application/x-rtp-stream,encoding-name=H264" ! rtpstreamdepay ! rtph264depay ! avdec_h264 ! videoconvert ! autovideosink sync=false
```

**Explanation:**
-   `tcpclientsrc`: Connects to the server.
-   `rtpstreamdepay`: Extracts RTP packets from the TCP stream (handles framing).
-   `rtph264depay`: Extracts H.264 video data from RTP packets.
-   `avdec_h264`: Decodes the H.264 frames.
-   `autovideosink`: Displays the video (ensure `sync=false` for lowest latency).

## 3. Telemetry (UDP)

The robot sends telemetry data to the `recv_udp_port` you specified during registration.

**Data Format:** JSON strings sent as UDP packets.

**Example Packet:**
```json
{
  "type": "real_vel",
  "linear_x": 0.5,
  "angular_z": 0.1
}
```
