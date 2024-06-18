import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DANF - MQTT',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  static List<Widget> _widgetOptions = <Widget>[
    MyHomePage(),
    IPPage(),
    CenasPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.public),
            label: 'MQTT',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'IP',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            label: 'Cenas',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final String server = 'super-author.cloudmqtt.com';
  final int port = 1883;
  final String username = 'tdmstjgu';
  final String password = 'mBv2M7HusSx8';
  final String subscribeTopic = '/Danf/TESTE_2024/V3/Mqtt/Feedback';
  final String publishTopic = '/Danf/TESTE_2024/V3/Mqtt/Comando';

  MqttServerClient? client;
  bool _connected = false;
  String _receivedMessage = '';
  Timer? _timer;
  TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _timer?.cancel();
    client?.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    client = MqttServerClient(server, '');
    client!.port = port;
    client!.logging(on: true);
    client!.keepAlivePeriod = 20;
    client!.onDisconnected = _onDisconnected;
    client!.onConnected = _onConnected;
    client!.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client!.connectionMessage = connMessage;

    try {
      await client!.connect(username, password);
    } catch (e) {
      print('Exception: $e');
      client!.disconnect();
    }

    if (client!.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT client connected');
      setState(() {
        _connected = true;
      });
      _startSendingMessages();
    } else {
      print('ERROR: MQTT client connection failed - disconnecting, state is ${client!.connectionStatus!.state}');
      client!.disconnect();
    }

    client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String pt =
      MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print('Received message: $pt from topic: ${c[0].topic}>');
      setState(() {
        _receivedMessage = pt;
      });
    });

    client!.subscribe(subscribeTopic, MqttQos.atMostOnce);
  }

  void _startSendingMessages() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _publish('SA');
    });
  }

  void _onConnected() {
    print('Connected');
  }

  void _onDisconnected() {
    print('Disconnected');
    setState(() {
      _connected = false;
    });
  }

  void _onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  Future<void> _publish(String message) async {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client!.publishMessage(publishTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('DANF - MQTT'),
        ),
        body: Padding(
        padding: const EdgeInsets.all(16.0),
    child: Column
      (
      children: <Widget>[
        Text(
          'Status: ${_connected ? 'Connected' : 'Disconnected'}',
          style: TextStyle(fontSize: 20),
        ),
        TextField(
          controller: _textController,
          decoration: InputDecoration(
            labelText: 'Message',
          ),
          onSubmitted: (text) {
            if (_connected) {
              _publish(text);
            }
          },
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            if (_connected) {
              _publish(_textController.text);
            }
          },
          child: Text('OK'),
        ),
        SizedBox(height: 20),
        Text(
          'Received: $_receivedMessage',
          style: TextStyle(fontSize: 16),
        ),
      ],
    ),
        ),
    );
  }
}

class IPPage extends StatefulWidget {
  @override
  _IPPageState createState() => _IPPageState();
}

class _IPPageState extends State<IPPage> {
  String _scanResult = '';

  Future<void> _startScan() async {
    // UDP socket for sending the broadcast message
    RawDatagramSocket? udpSocket;

    try {
      udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      udpSocket.broadcastEnabled = true;

      final String broadcastAddress = '255.255.255.255';
      final int port = 5555;

      // Send broadcast message
      udpSocket.send(utf8.encode('<SI>'), InternetAddress(broadcastAddress), port);

      // Listen for response for 2 seconds
      await Future.delayed(Duration(seconds: 2));

      // Receive response
      await for (var datagram in udpSocket) {
        if (datagram == RawSocketEvent.read) {
          Datagram dg = udpSocket.receive()!;
          String response = utf8.decode(dg.data);
          List<String> info = extractInfo(response);
          setState(() {
            _scanResult = info.join('\n'); // Alteração aqui
          });
          break;
        }
      }
    } catch (e) {
      print('Error during scan: $e');
    } finally {
      udpSocket?.close();
    }
  }

  List<String> extractInfo(String message) {
    RegExp regex = RegExp(r"<([^>]+)><([^>]+)><([^>]+)><([^>]+)>");
    Match? match = regex.firstMatch(message);

    if (match != null) {
      String name = match.group(1)!;
      String ip = match.group(2)!;
      String mac = match.group(3)!;
      String version = match.group(4)!;
      return ['Name: $name', 'IP: $ip', 'MAC: $mac', 'Version: $version'];
    } else {
      print("A mensagem não está no formato esperado.");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IP Page'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _startScan,
              child: Text('Start Scan'),
            ),
            SizedBox(height: 20),
            Text(
              _scanResult,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center, // Ajuste aqui
            ),
          ],
        ),
      ),
    );
  }
}

class CenasPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cenas Page'),
      ),
      body: Center(
        child: Text(
          'Cenas Page Content',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

