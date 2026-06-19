# OptiRide Controller

Flutter controller app for an ESP32-CAM car over LAN.

## What it does

- Manual ESP32 IP entry
- Direct HTTP control over the local network
- MJPEG camera preview from `http://<ip>:81/stream`
- Drive, steer, light, emergency stop, keyboard, joystick, and gyro control
- No cloud, no backend, no relay service
- ESP32 firmware serves only API endpoints and the camera stream

## Firmware routes

The app talks to the firmware using these GET endpoints:

- `/ping`
- `/stream`
- `/forward`
- `/backward`
- `/steerleft`
- `/steerright`
- `/stopdrive`
- `/stopsteer`
- `/stopall`
- `/lighton`
- `/lightoff`
- `/lighttoggle`

## Notes

- Android cleartext HTTP is enabled because the device is accessed over LAN.
- The current Flutter implementation targets mobile and desktop. Web is not a supported target for the direct `dart:io` streaming path.

