import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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
      home: const ControllerAndCamera(title: 'Controller'),
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
  BluetoothCharacteristic? txCharacteristic;
  double xval1 = 0;
  double yval1 = 0;
  double xval2 = 0;
  double yval2 = 0;

  List<ScanResult> ScanResults = [];
  Map<String, ScanResult> FilteredScanResults = {};
  BluetoothDevice? connectedDevice;
  bool isScanning = false;

  GoogleMapController? _mapController;
  LatLng? _currentPosition; // Nullable so we can wait for GPS fix

  late StreamSubscription<Position> _positionStream;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _initLocationTracking();

    Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (txCharacteristic == null) return;

      // Convert steering to PWM (linear)
      double steerPwm = (1500 + (xval1 * 500)).clamp(1000, 2000);

      // Convert throttle using exponential curve
      double escPwm = expEsc(-yval2);  // negative because forward is down

      String packet = "${steerPwm.toInt()},${escPwm.toInt()}\n";

      txCharacteristic!.write(
        utf8.encode(packet),
        withoutResponse: true,
      );
    });

  }

  double expEsc(double x) {
    const k = 3.0;

    if (x.abs() < 0.02) return 1500;

    double t = x.abs();
    double f = (exp(k * t) - 1) / (exp(k) - 1);

    double pwm = x > 0
        ? 1500 + (f * 500)
        : 1500 - (f * 500);

    return pwm.clamp(1000, 2000);
  }

  Future<void> _initLocationTracking() async {
    final permission = await Permission.location.request();
    if (!permission.isGranted) return;

    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(pos.latitude, pos.longitude);
    });

    const locationOptions = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationOptions)
            .listen((Position position) {
          _currentPosition = LatLng(position.latitude, position.longitude);

          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: _currentPosition!,
                  zoom: 16,
                ),
              ),
            );
          }
        });
  }

  @override
  void dispose() {
    _positionStream.cancel();
    super.dispose();
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
        if (foundDevice.device.advName.isNotEmpty) {
          setState(() {
            FilteredScanResults[foundDevice.device.advName] = foundDevice;
          });
        }
      }
    });

    FlutterBluePlus.isScanning.listen((scanning) {
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
          title: const Text('Controller'),
          centerTitle: true,
          backgroundColor: Colors.teal,
          // Removed top-right refresh button
        ),

        drawer: SafeArea(
          child: Drawer(
            child: Column(
              children: [
                // Drawer header with inline refresh button
                DrawerHeader(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Available Devices",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: startScan,
                      ),
                    ],
                  ),
                ),
                isScanning
                    ? const CircularProgressIndicator()
                    : Expanded(
                  child: ListView(
                    children: FilteredScanResults.values
                        .map<Widget>((item) => ListTile(
                      onTap: () async {
                        await FlutterBluePlus.stopScan();
                        await item.device.connect(license: License.free);
                        setState(() => connectedDevice = item.device);

                        // Discover services + set up write characteristic
                        var services = await item.device.discoverServices();
                        for (var s in services) {
                          for (var c in s.characteristics) {
                            if (c.properties.write) {
                              txCharacteristic = c;
                            }
                          }
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Connected to ${item.device.advName}")),
                        );
                      },
                      title: Text(item.advertisementData.advName),
                    ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        body: Stack(
          children: [
            // Show loading until GPS is ready
            if (_currentPosition != null)
              GoogleMap(
                onMapCreated: (controller) => _mapController = controller,
                initialCameraPosition: CameraPosition(
                  target: _currentPosition!,
                  zoom: 16,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                compassEnabled: false,
                zoomGesturesEnabled: false,
                scrollGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
              )
            else
              const Center(
                child: CircularProgressIndicator(),
              ),

            // Bottom-left joystick
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  width: 150,
                  height: 150,
                  child: Joystick(
                    mode: JoystickMode.all,
                    listener: (details) {
                      xval1 = details.x;
                      yval1 = details.y;
                    },
                  ),
                ),
              ),
            ),

            // Bottom-right joystick
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  width: 150,
                  height: 150,
                  child: Joystick(
                    mode: JoystickMode.all,
                    listener: (details) {
                      xval2 = details.x;
                      yval2 = details.y;
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
