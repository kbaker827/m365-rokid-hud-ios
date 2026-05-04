# M365 Rokid HUD iOS


> **🔵 Connectivity Update — May 2025**
> The glasses connection has been migrated from **raw TCP sockets** to
> **Bluetooth via the Rokid AI glasses SDK** (`pod 'RokidSDK' ~> 1.10.2`).
> No Wi-Fi port forwarding is needed. See **SDK Setup** below.

iOS companion app for displaying Xiaomi M365 / Ninebot scooter telemetry on Rokid AR glasses.

Converted from the Android original. Replaces the Rust FFI native library with a pure-Swift implementation of the open Ninebot serial protocol.

## What it does

- **BLE scan**: Discovers nearby M365/Ninebot scooters (filters by device name prefix).
- **GATT connection**: Connects to the Nordic UART Service (NUS) on the scooter.
- **Live telemetry polling** every 500ms:
  - Speed (km/h or mph)
  - Battery % 
  - Temperature (°C)
  - Trip distance (m)
  - Total odometer (km)
  - Remaining range (km)
  - Error code
- **Alerts**: Configurable speed-limit and low-battery warnings.
- **Glasses HUD**: TCP server on port 8086 streams JSON telemetry lines to connected Rokid glasses.
- **Imperial/metric toggle**.

## Android → iOS mapping

| Android | iOS |
|---------|-----|
| `M365Native` (Rust FFI `ninebot_ffi`) | `NinebotProtocol` (pure Swift frame builder/parser) |
| `BleManager` (Android BluetoothGatt) | `M365BleManager` (CoreBluetooth) |
| `ScooterRepository` | `HudViewModel` |
| `WifiGatewayServer` | `GlassesServer` (NWListener TCP :8086) |
| `DashboardScreen` | `DashboardView` + `ScanView` |

## Protocol note

The Android app uses a closed-source Rust library (`ninebot_ffi`) for the encrypted Ninebot handshake required by newer Mi Pro / Pro 2 scooters. This iOS conversion implements the **open Ninebot serial protocol** frame format, which handles all read-only telemetry on M365 and most Ninebot E-series scooters without encryption. Scooters that require encrypted auth will connect at the GATT level but may return no data.

## Ninebot UART frame format

```
[0x55][0xAA][len][src][dst][cmd][attr][payload...][crc16_lo][crc16_hi]
```

Service UUIDs:
- Service:  `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- Write TX: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- Notify RX:`6E400003-B5A3-F393-E0A9-E50E24DCCA9E`

## Glasses protocol (TCP :8086)

```json
{"type":"telemetry","speedKmh":18.4,"batteryPercent":62,"tempCelsius":31.0,"tripMeters":4200,"totalKm":1842.3,"remainingKm":22.5,"errorCode":0}
{"type":"status","text":"Connected to scooter"}
```

## SDK Setup

The glasses now connect over **Bluetooth via the Rokid AI glasses SDK** — no Wi-Fi port or TCP server needed.

The only thing left for each app is filling in the three credential constants (`kAppKey`, `kAppSecret`, `kAccessKey`) from [account.rokid.com/#/setting/prove](https://account.rokid.com/#/setting/prove), then running `pod install`.

1. **Get credentials** at <https://account.rokid.com/#/setting/prove> and paste them into the glasses Swift file:
   ```swift
   private let kAppKey    = "YOUR_APP_KEY"
   private let kAppSecret = "YOUR_APP_SECRET"
   private let kAccessKey = "YOUR_ACCESS_KEY"
   ```

2. **Install CocoaPods dependencies** from the repo root:
   ```bash
   pod install
   open *.xcworkspace   # always open the .xcworkspace, not .xcodeproj
   ```

3. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Setup

1. Open `M365HUD.xcodeproj` in Xcode 15+.
2. Set your team in Signing & Capabilities.
3. Build and run on an iPhone (iOS 17+).
4. Allow Bluetooth permission when prompted.
5. Tap **Scan** to find your scooter.
6. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Requirements

- iOS 17.0+
- Xcode 15+
- Xiaomi M365, M365 Pro, or compatible Ninebot scooter
