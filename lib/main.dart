import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';

import 'package:location_permissions/location_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:settings_ui/settings_ui.dart';

SettingsOptions settingsOptions = SettingsOptions();
late QualifiedCharacteristic rxCharacteristic;
late QualifiedCharacteristic txCharacteristic;
bool foundDevice = false;
bool deviceConnected = false;
final flutterReactiveBle = FlutterReactiveBle();

enum Pieces {
  whitePawn,
  whiteKing,
  whiteQueen,
  whiteBishop,
  whiteRook,
  whiteKnight,
  blackPawn,
  blackKing,
  blackQueen,
  blackBishop,
  blackRook,
  blackKnight,
  none,
}
List<AssetImage> figures = <AssetImage> [
  const AssetImage('assets/white_pawn.png'),
  const AssetImage('assets/white_king.png'), 
  const AssetImage('assets/white_queen.png'), 
  const AssetImage('assets/white_bishop.png'), 
  const AssetImage('assets/white_rook.png'), 
  const AssetImage('assets/white_knight.png'), 

  const AssetImage('assets/black_pawn.png'),
  const AssetImage('assets/black_king.png'), 
  const AssetImage('assets/black_queen.png'), 
  const AssetImage('assets/black_bishop.png'), 
  const AssetImage('assets/black_rook.png'), 
  const AssetImage('assets/black_knight.png'), 
];


void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const StartPage(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
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
    if (permGranted) {
      _scanStream = flutterReactiveBle
          .scanForDevices(withServices: [serviceUuid]).listen((device) {
        if (device.name == 'ENCHESS') {
          foundDevice = true;
          enchessDevice = device;
          _connectToDevice();
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
            withServices: [serviceUuid]);
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
            flutterReactiveBle.requestMtu(deviceId: event.deviceId, mtu: 264);
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

    _startScan();
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
                    builder: (context) => const GamePage(),
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

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  int elapsedTime = 0;
  String timeformated = '00 : 00 : 00';
  late Timer timeCounter;
  List<Pieces> pieces = List.filled(64, Pieces.none);

  int ptbRatio = 12; 

  double _calcChessboardSize(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return width > height ? height : width;
  }

  Stack _assembleChessboard() {
    return Stack(
      children: [
        Image(
          image: const AssetImage('assets/chessboard.png'),
          width: _calcChessboardSize(context),
          height: _calcChessboardSize(context),
        ),
        ...List.generate(8, (r) {
          return Padding(
            padding: EdgeInsets.only(top: _calcChessboardSize(context) * ( (2 * r + 1) * (1 / 8 - 1 / ptbRatio) * 0.5 + r / ptbRatio)),
            child: Row(
              children:
                List.generate(8, (c) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: _calcChessboardSize(context) * (1 / 8 - 1 / ptbRatio) * 0.5),
                    child: (pieces[c * 8 + r] != Pieces.none) ? 
                      Image(
                        image: figures[pieces[c * 8 + r].index],
                        width: _calcChessboardSize(context) / ptbRatio,
                        height: _calcChessboardSize(context) / ptbRatio,
                      )
                      : SizedBox(width: _calcChessboardSize(context) / ptbRatio, height: _calcChessboardSize(context) / ptbRatio,),
                  );
                }),
            ),
          );
        }),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    timeCounter = Timer.periodic(const Duration(seconds: 1),
      (timer) { 
        setState(() { 
            elapsedTime++; 
            timeformated  = (elapsedTime ~/ 3600).toString().padLeft(2, '0');
            timeformated += ':';
            timeformated += ((elapsedTime % 3600) ~/ 60).toString().padLeft(2, '0');
            timeformated += ':';
            timeformated += (elapsedTime % 60).toInt().toString().padLeft(2, '0');
          }
        ); 
      }
    );
    if (deviceConnected) {
      flutterReactiveBle.subscribeToCharacteristic(rxCharacteristic).listen((data) {
          Iterable l = json.decode(utf8.decode(data));
          pieces = List<Pieces>.from(l.map((index) => Pieces.values[index]));
          print(utf8.decode(data));
        }
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title:  const Text('Enchess'),
        leading:  IconButton(
          onPressed: () {Navigator.pop(context);},
          icon: const Icon(Icons.arrow_back),
        )
      ),
      body: Column(
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 15.0),
                child: Text('Text'),
              ),
              const Spacer(),
              const Center(child: Text('Text')),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: Text(timeformated),
              ),
            ],
          ),
          _assembleChessboard(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timeCounter.cancel();
    super.dispose();
  }
}

class SettingsOptions {
  bool darkMode = false;
  int moveTime = 10;
  bool color = true; // true = white, false = black

  SettingsOptions();

  SettingsOptions.fromJson(Map<String, dynamic> json)
      : moveTime = json['moveTime'],
        color    = json['color'];

  Map<String, dynamic> toJson() => {
        'moveTime': moveTime,
        'color'   : color,
      };
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
    JsonUtf8Encoder encoder = JsonUtf8Encoder();
    return encoder.convert(settingsOptions);
  }
  void writeSettings() {
    if (deviceConnected) {
      flutterReactiveBle.writeCharacteristicWithResponse(txCharacteristic, value: settingsToInt());
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
