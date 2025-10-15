// Flutter Bluetooth Chat — Starter (Android, Bluetooth Classic)
// File: lib/main.dart
// Notes: This starter uses flutter_bluetooth_serial (Bluetooth Classic / SPP)
// Android-only: iOS does not support SPP without special entitlements (MFi).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Bluetooth Chat',
      theme: ThemeData(primarySwatch: Colors.indigo),
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
  final FlutterBluetoothSerial _bt = FlutterBluetoothSerial.instance;
  List<BluetoothDevice> _devicesList = [];
  BluetoothConnection? _connection;
  bool _isConnecting = false;
  bool get _isConnected => _connection != null && _connection!.isConnected;
  final List<_Message> _messages = [];
  final TextEditingController _textCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getBondedDevices();
  }

  Future<void> _getBondedDevices() async {
    try {
      var devices = await _bt.getBondedDevices();
      setState(() => _devicesList = devices);
    } catch (e) {
      debugPrint('Error getting bonded devices: $e');
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_isConnecting || _isConnected) return;
    setState(() => _isConnecting = true);
    try {
      final conn = await BluetoothConnection.toAddress(device.address);
      debugPrint('Connected to the device');
      setState(() {
        _connection = conn;
        _isConnecting = false;
      });

      conn.input?.listen((Uint8List data) {
        final text = utf8.decode(data);
        setState(() => _messages.add(_Message(text, false)));
      }).onDone(() {
        debugPrint('Disconnected by remote');
        setState(() {
          _connection = null;
        });
      });
    } catch (e) {
      debugPrint('Cannot connect, exception: $e');
      setState(() => _isConnecting = false);
    }
  }

  void _sendMessage(String text) {
    if (!_isConnected || text.isEmpty) return;
    try {
      _connection!.output.add(utf8.encode(text + "\n"));
      _messages.add(_Message(text, true));
      _textCtrl.clear();
      setState(() {});
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> _disconnect() async {
    if (_isConnected) {
      await _connection?.close();
      setState(() => _connection = null);
    }
  }

  @override
  void dispose() {
    _disconnect();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Chat (Android)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getBondedDevices,
          )
        ],
      ),
      body: Container(
        color: Colors.blue[100], // Set blue background color
        child: Column(
          children: [
            Expanded(child: _buildDevicesList()),
            const Divider(),
            Expanded(child: _buildChat()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesList() {
    return ListView.builder(
      itemCount: _devicesList.length,
      itemBuilder: (context, i) {
        final d = _devicesList[i];
        return ListTile(
          title: Text(d.name ?? 'Unknown'),
          subtitle: Text(d.address),
          trailing: ElevatedButton(
            child: Text(_isConnected ? 'Connected' : 'Connect'),
            onPressed: _isConnected ? null : () => _connectToDevice(d),
          ),
        );
      },
    );
  }

  Widget _buildChat() {
    return ListView.builder(
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        return Align(
          alignment: m.fromMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: m.fromMe ? Colors.blueAccent : Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(m.text, style: TextStyle(color: m.fromMe ? Colors.white : Colors.black)),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: TextField(
                controller: _textCtrl,
                decoration: const InputDecoration(hintText: 'Type message'),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _sendMessage(_textCtrl.text.trim()),
          )
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool fromMe;
  _Message(this.text, this.fromMe);
}

/*
README / Usage Notes (also in-app):

Dependencies (pubspec.yaml):
  flutter_bluetooth_serial: ^0.4.0

AndroidManifest permissions (Android 12+ and location for discovery):
  <uses-permission android:name="android.permission.BLUETOOTH" />
  <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
  <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
  <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

Notes:
- This starter targets Bluetooth Classic (SPP). Works on Android only.
- For cross-platform (Android+iOS) you must use BLE; packages: flutter_reactive_ble (central), flutter_ble_peripheral (advertise on Android). iOS advertising from app is limited.
- Message framing here is naive ("\n" terminated). Consider a simple protocol or length-prefix for production.
- Handle runtime permissions for Android 12+ before scanning/connecting.
*/
