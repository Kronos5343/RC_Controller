// This code will provide a button for the user to scan for bluetooth devices
// using two different approaches:
//    * Classic - Devices usually used with continuous data streaming or file sharing
//    * BLE (Bluetooth Low Energy) - Devices usually used with intermittent communication
//
// Some devices may transmit on both Classic and BLE using the same ID.
// The devices found will be displayed on the Logcat window or the Run window.

import 'dart:async';
import 'package:flutter/material.dart';

// There are overlaps in the names of the classes for clsasic and ble.  Using
// aliases to keep the namespaces different.
import 'package:flutter_blue_classic/flutter_blue_classic.dart' as classic;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Demo',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  // Need an instance for the classic plugin.  The BLE plugin does not have this requirement.
  final _flutterBlueClassicPlugin = classic.FlutterBlueClassic();

  // Results are stored in a map to prevent duplicates
  final Map<String, classic.BluetoothDevice> _classicScanResults = {};
  final Map<ble.DeviceIdentifier, ble.ScanResult> _bleScanResults = {};

  // The active scan
  StreamSubscription? _classicScanSubscription;
  StreamSubscription? _bleScanSubscription;

  // Listeners for whether we are scanning
  StreamSubscription? _classicScanningStateSubscription;
  StreamSubscription? _bleScanningStateSubscription;

  // Are we scanning
  bool _classicIsScanning = false;
  bool _bleIsScanning = false;

  @override
  void initState() {
    super.initState();

    // Initialize the scanner for Classic while will last the entire
    // time the app is running
    initClassic();
    initBLE();
  }

  Future<void> initClassic() async {
    // This will register for bluetooth classical devices for the life of the app
    // When a scan starts, it will put the results in the map.
    _classicScanSubscription = _flutterBlueClassicPlugin.scanResults.listen((device) {
      // The result contains a single device to add to our map
      setState(() => _classicScanResults[device.address] = device);
    });

    // It will also detect if scanning is active and automatically set isScanning
    _classicScanningStateSubscription = _flutterBlueClassicPlugin.isScanning.listen((isScanning) {
      debugPrint("Classic STATE: $isScanning");
      setState(() => _classicIsScanning = isScanning);
    });
  }

  Future<void> initBLE() async {
    // This will register for bluetooth BLE devices for each individual scan
    // When a device is found, it will put in the map
    _bleScanSubscription = ble.FlutterBluePlus.onScanResults.listen((results) {
      // The results contain all the results.  We will just look at the new one at the end
      // to add to our map
      if (results.isNotEmpty) {
        setState(() => _bleScanResults[results.last.device.remoteId] = results.last);
      }
    });

    // It will also detect if scanning is active and automatically set isScanning
    _bleScanningStateSubscription = ble.FlutterBluePlus.isScanning.listen((isScanning) {
      debugPrint("BLE STATE: $isScanning");
      setState(() => _bleIsScanning = isScanning);
    });
  }

  @override
  void dispose() {
    // Cleanup the scans if in progress
    _classicScanSubscription?.cancel();
    _classicScanningStateSubscription?.cancel();
    _bleScanSubscription!.cancel();
    _bleScanningStateSubscription!.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    // If the result maps are updated when no scanning is occurring, then
    // we should display the final results.  THe
    // classic scan remains for the entire app.
    if (!_classicIsScanning && !_bleIsScanning) {
      // Display Results
      debugPrint("---START CLASSIC SCAN RESULTS---");
      for (var d in _classicScanResults.values) {
        if (d.name != null && d.name!.isNotEmpty) {
          debugPrint("${d.name} | ${d.address} | ${d.rssi}");
        }
      }
      debugPrint("---END CLASSIC SCAN RESULTS---");

      debugPrint("---START BLE SCAN RESULTS---");
      for (var d in _bleScanResults.values) {
        if (d.advertisementData.advName.isNotEmpty) {
          debugPrint(
              "${d.advertisementData.advName} | ${d.device.remoteId} | ${d
                  .rssi}");
        }
      }
      debugPrint("---END BLE SCAN RESULTS---");

    }

    return Scaffold(

      // When the user presses the button, it will initiate (or stop) the
      // scan
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // If we weren't scanning anything before, then we want to start a new scan
          if (!_classicIsScanning && !_bleIsScanning) {
            // Clear the maps containing the bluetooth results
            _classicScanResults.clear();
            _bleScanResults.clear();

            // Start the Classic Scan.  This runs for about 15 seconds
            _flutterBlueClassicPlugin.startScan();

            // Start the BLE Scan for 15 seconds.
            ble.FlutterBluePlus.startScan(timeout: Duration(seconds:15));
          }
          else {
            // If we are currently scanning something, then we will stop the scans
            // which will trigger the current device maps to be displayed.
            _flutterBlueClassicPlugin.stopScan();
            ble.FlutterBluePlus.stopScan();
          }
        },
        label: Text(_classicIsScanning || _bleIsScanning ? "Scanning..." : "Start device scan"),
        icon: Icon(_classicIsScanning || _bleIsScanning ? Icons.bluetooth_searching : Icons.bluetooth),
      ),


    );
  }
}
