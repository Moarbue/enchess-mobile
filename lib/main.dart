import 'dart:async';
import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:location_permissions/location_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:settings_ui/settings_ui.dart';

SettingsOptions settingsOptions = SettingsOptions();
late QualifiedCharacteristic rxCharacteristic;
late QualifiedCharacteristic txCharacteristic;
bool deviceConnected = false;
final flutterReactiveBle = FlutterReactiveBle();


void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: StartPage(),
    );
  }
}

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
// Bluetooth related variables
  late DiscoveredDevice enchessDevice;

  late StreamSubscription<DiscoveredDevice> _scanStream;

// These are the UUIDs of your device
  final Uuid serviceUuid          = Uuid.parse("bec6075b-97fc-4f3b-a693-f98ace1b5913");
  final Uuid rxcharacteristicUuid = Uuid.parse("ec344566-b4c4-48ca-ad36-a3317b42fbde");
  final Uuid txcharacteristicUuid = Uuid.parse("fb3a5803-d9f9-46b7-b418-9423a7320c08");

  Future<bool> _startScan() async {
// Platform permissions handling stuff
    bool permGranted = false;
    PermissionStatus permission;
    if (Platform.isAndroid) {
      permission = await LocationPermissions().requestPermissions();
      if (permission == PermissionStatus.granted) permGranted = true;
    } else if (Platform.isIOS) {
      permGranted = true;
    }
// Main scanning logic happens here ⤵️
    bool foundDevice = false;
    if (permGranted) {
      _scanStream = flutterReactiveBle
          .scanForDevices(withServices: [serviceUuid]).listen((device) {
        if (device.name == 'ENCHESS') {
          setState(() {
            foundDevice = true;
            enchessDevice = device;
          });
        }
      });
    }
    return foundDevice;
  }

  void _connectToDevice() {
    // We're done scanning, we can cancel it
    _scanStream.cancel();
    // Let's listen to our connection so we can make updates on a state change
    Stream<ConnectionStateUpdate> currentConnectionStream = flutterReactiveBle
        .connectToAdvertisingDevice(
            id: enchessDevice.id,
            prescanDuration: const Duration(seconds: 1),
            withServices: [serviceUuid, rxcharacteristicUuid, txcharacteristicUuid]);
    currentConnectionStream.listen((event) {
      switch (event.connectionState) {
        // We're connected and good to go!
        case DeviceConnectionState.connected:
          {
            rxCharacteristic = QualifiedCharacteristic(
                serviceId: serviceUuid,
                characteristicId: rxcharacteristicUuid,
                deviceId: event.deviceId);
            txCharacteristic = QualifiedCharacteristic(
                serviceId: serviceUuid,
                characteristicId: txcharacteristicUuid,
                deviceId: event.deviceId);
            setState(() {
              deviceConnected = true;
            });
            break;
          }
        // Can add various state state updates on disconnect
        case DeviceConnectionState.disconnected:
          {
            break;
          }
        default:
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _startScan().then((value) { if (value) _connectToDevice(); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'ENCHESS',
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const Placeholder(),
                  ),
                );
              },
              child: const Text('Start'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ),
                );
              },
              child: const Text('Settings'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const InfoPage(),
                  ),
                );
              },
              child: const Text('Info'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsOptions {
  bool darkMode = false;
  int moveTime = 10;
  bool color = true; // true = white, false = black
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  TextEditingController moveTimeController = TextEditingController();

  SizedBox _numberTextField(TextEditingController controller, void Function(String)? onChanged, hint, double width) {
    return SizedBox(
      width: width,
      child: TextField(
        onChanged: onChanged,
        controller: controller,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.all(10),
          filled: true,
          hintText: hint,
        ),
      ),
    );
  }

  List<int> settingsToInt() {
    return <int> [0xff,];
  }
  void writeSettings() {
    if (deviceConnected) {
      flutterReactiveBle.writeCharacteristicWithResponse(rxCharacteristic, value: settingsToInt());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          centerTitle: true,
          title: const Text('Settings'),
          leading: IconButton(
            onPressed: () {
              writeSettings();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
          )),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: const Text('General'),
            tiles: <SettingsTile>[
              SettingsTile.switchTile(
                initialValue: settingsOptions.darkMode,
                onToggle: (state) {
                  setState(() {
                    settingsOptions.darkMode = state;
                  });
                },
                title: const Text('Dark Mode'),
                leading: const Icon(Icons.dark_mode_rounded),
              ),
              SettingsTile(
                title: const Text('Move Time'),
                trailing: _numberTextField(
                  moveTimeController, 
                  (value) { settingsOptions.moveTime = int.tryParse(moveTimeController.text) ?? SettingsOptions().moveTime; },
                  'sec', 
                  60
                ),
              ),
              SettingsTile(
                title: const Text('Color'),
                trailing: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () { setState(() { settingsOptions.color = true; }); },
                      child: Container(
                        width: 45,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: settingsOptions.color ? Border.all(color: Colors.red) : Border.all(color: Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 30,),
                    GestureDetector(
                      onTap: () { setState(() { settingsOptions.color = false; }); },
                      child: Container(
                        width: 45,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: !settingsOptions.color ? Border.all(color: Colors.red) : Border.all(color: Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('Thomas Kaufmann'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
