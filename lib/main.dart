import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const MainScreen());
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: ControllerAndCamera(title: 'Controller'),
    );
  }
}


class ControllerAndCamera extends StatefulWidget {
  const ControllerAndCamera({super.key, required this.title});
  final String title;
  @override
  State<ControllerAndCamera> createState() => _ControllerAndCameraState();
}

class _ControllerAndCameraState extends State<ControllerAndCamera> {
  double xval1 = 0;
  double yval1 = 0;
  double xval2 = 0;
  double yval2 = 0;
//if (device.name.isNotEmpty && device.name != null)
  // final Map<ble.DeviceIdentifier, ble.ScanResult> ScanResults = {};
  List<ScanResult> ScanResults = [];
  Map<String ,ScanResult> FilteredScanResults = {};
  BluetoothDevice? connectedDevice;
  bool isScanning = false;

  @override
  void initState(){
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();

    startScan();
  }
  void startScan() {
    setState(() {
      isScanning = true;
      ScanResults.clear();
      FilteredScanResults.clear();
    });
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) {
      for (var foundDevice in results) {
        // Only add devices that have names and aren’t duplicates
        if (foundDevice.device.advName.isNotEmpty) {
          setState(() {
            FilteredScanResults[foundDevice.device.advName] = foundDevice;
          });
        }
      }
    });
    FlutterBluePlus.isScanning.listen((scanning){
      setState(() => isScanning = scanning);
    });
  }

  Future<void> ConnectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    await device.connect(license: License.free);
    setState(() => connectedDevice = device);
  }

  Future<void> disconnect() async {
    await connectedDevice?.disconnect();
    setState(() => connectedDevice = null);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Controller'),
          centerTitle: true,
          backgroundColor: Colors.teal,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: startScan,
            )
          ],
        ),
        drawer: SafeArea(
          child: Drawer(
            child: Column(
              children: [
                const DrawerHeader(
                  child: Text("Available Devices"),
                ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: (){startScan();},
                    ),
                isScanning
                    ? CircularProgressIndicator():
                Expanded(
                  child: ListView(
                    children: FilteredScanResults.values.map<Widget>((var item) =>
                        ListTile(
                        onTap:(){debugPrint("${item.device.advName}");},
                            title: Text(item.advertisementData.advName))).toList(),


                  )
                ),

              ]
            )
          )
        ),
        body: Stack(
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Joystick(
                  mode: JoystickMode.all,
                  listener: (details) {
                    setState(() {
                      xval1 = details.x;
                      yval1 = details.y;
                    });
                    // Send X and Y via Bluetooth Here



                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Joystick(
                  mode: JoystickMode.vertical,
                  listener: (details) {
                    setState(() {
                      xval2 = details.x;
                      yval2 = details.y;
                    });
                    // Send X and Y via Bluetooth Here



                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
