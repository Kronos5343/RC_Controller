import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

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
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Controller'),
          centerTitle: true,
          backgroundColor: Colors.teal,
        ),
        drawer: SafeArea(
          child: Drawer(
            child: Column(
              children: [
                DrawerHeader(child: Text("Available devices"))
              ],
            ),
          ),
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
