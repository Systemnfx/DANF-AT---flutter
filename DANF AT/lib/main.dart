import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(MyApp());
}
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simula um tempo de espera antes de navegar para a próxima tela
    Timer(Duration(seconds: 3), () {
      // Navegar para a próxima tela após 3 segundos
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Cor de fundo da tela de apresentação
      body: Center(
        child: Image.asset('assets/img.jpg'),
      ),
    );
  }
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DANF - MQTT',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(), // Inicia com a SplashScreen
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
  String publishTopic = '/Danf/TESTE_2024/V3/Mqtt/Comando';
  String subscribeTopic = '/Danf/TESTE_2024/V3/Mqtt/Feedback';

  MqttServerClient? client;
  bool _connected = false;
  String _receivedMessage = '';
  Timer? _timer;
  TextEditingController _textController = TextEditingController();
  TextEditingController _topicController = TextEditingController(text: 'TESTE_2024'); // Valor padrão
  List<String> _suggestions = ['TESTE_2024', 'teste 1', 'teste 2'];

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
      final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print('Received message: $pt from topic: ${c[0].topic}>');
      setState(() {
        _receivedMessage = pt;
      });
    });

    _subscribeToTopic(subscribeTopic);
  }

  void _subscribeToTopic(String topic) {
    client!.subscribe(topic, MqttQos.atMostOnce);
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
    builder.addString(message.toUpperCase());
    client!.publishMessage(publishTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  void insertTopic() {
    String topic = _topicController.text.trim();

    // Atualiza os tópicos de publicação e subscrição
    publishTopic = '/Danf/$topic/V3/Mqtt/Comando';
    subscribeTopic = '/Danf/$topic/V3/Mqtt/Feedback';

    // Desconecta o cliente MQTT atual, se estiver conectado
    if (_connected) {
      _timer?.cancel();
      client?.disconnect();
    }

    // Cria e conecta um novo cliente MQTT com os novos tópicos
    _connect();
  }

  Widget _buildConnectionStatus() {
    return Row(
      children: [
        Text(
          'Status: ',
          style: TextStyle(fontSize: 20),
        ),
        Icon(
          _connected ? Icons.circle : Icons.circle,
          color: _connected ? Colors.lightGreen : Colors.red,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('DANF - MQTT'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildConnectionStatus(),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTopicInput(),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    insertTopic();
                  },
                  child: Text('OK'),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      labelText: 'Messagen',
                    ),
                    onSubmitted: (text) {
                      if (_connected) {
                        _publish(text);
                      }
                    },
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    if (_connected) {
                      _publish(_textController.text);
                    }
                  },
                  child: Text('Enviar'),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () {
                      if (_connected) {
                        _publish('OFAN');
                      }
                    },
                    child: Text('ON'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      if (_connected) {
                        _publish('OFAO');
                      }
                    },
                    child: Text('OFF'),
                  ),
                ),
              ],
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

  Widget _buildTopicInput() {
    return Stack(
      children: [
        TextField(
          controller: _topicController,
          decoration: InputDecoration(
            labelText: 'Tópico',
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
        Positioned(
          right: 0,
          top: 8,
          child: IconButton(
            icon: Icon(Icons.arrow_drop_down),
            onPressed: () {
              _showSuggestions();
            },
          ),
        ),
      ],
    );
  }

  void _showSuggestions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          children: _suggestions.map((suggestion) {
            return ListTile(
              title: Text(suggestion),
              onTap: () {
                setState(() {
                  _topicController.text = suggestion;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }
}


class IPPage extends StatefulWidget {
  @override
  _IPPageState createState() => _IPPageState();
}

class _IPPageState extends State<IPPage> {
  String _scanResult = '';
  Timer? _scanTimer;
  Socket? _socket;
  TextEditingController _messageController = TextEditingController();
  String _receivedMessage = '';
  Timer? _sendingSATimer; // Timer para enviar 'SA' a cada segundo

  @override
  void initState() {
    super.initState();
    _startScanLoop();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _socket?.close();
    _sendingSATimer?.cancel(); // Cancela o timer de envio de 'SA'
    super.dispose();
  }

  void _startScanLoop() {
    _scanTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      _startScan();
    });
  }

  Future<void> _startScan() async {
    RawDatagramSocket? udpSocket;

    try {
      udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      udpSocket.broadcastEnabled = true;

      final String broadcastAddress = '255.255.255.255';
      final int port = 5555;

      udpSocket.send(utf8.encode('<SI>'), InternetAddress(broadcastAddress), port);

      await Future.delayed(Duration(seconds: 1));

      await for (var datagram in udpSocket) {
        if (datagram == RawSocketEvent.read) {
          Datagram dg = udpSocket.receive()!;
          String response = utf8.decode(dg.data);
          List<String> info = extractInfo(response);
          setState(() {
            _scanResult = info[1]; // IP address
          });
          if (_scanResult.isNotEmpty) {
            _scanTimer?.cancel();
            _connectToServer(_scanResult);
          }
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
      return [name, ip, mac, version];
    } else {
      print("A mensagem não está no formato esperado.");
      return [];
    }
  }

  Future<void> _connectToServer(String ip) async {
    try {
      _socket = await Socket.connect(ip, 8080);
      _socket!.listen(
        (data) {
          setState(() {
            _receivedMessage = utf8.decode(data);
          });
        },
        onError: (error) {
          print('Socket error: $error');
          _socket?.destroy();
        },
        onDone: () {
          print('Server closed connection');
          _socket?.destroy();
        },
      );
      print('Connected to: $ip');
      _startSendingSA(); // Inicia o envio da mensagem 'SA'
    } catch (e) {
      print('Error connecting to server: $e');
    }
  }

  // Função para enviar a mensagem 'SA' a cada 1 segundo
  void _startSendingSA() {
    _sendingSATimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _sendMessage('SA');
    });
  }

  Future<void> _sendMessage(String message) async {
    if (_socket != null) {
      message = '<$message>'.toUpperCase();
      _socket!.write(message);
      print('Message sent: $message');
    } else {
      print('Socket is not connected');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IP Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'IP: ${_scanResult.isNotEmpty ? _scanResult : 'Buscando a central...'}',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Mensagem',
                    ),
                    onSubmitted: (text) {
                      if (_scanResult.isNotEmpty) {
                        _sendMessage(text);
                      }
                    },
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    if (_scanResult.isNotEmpty) {
                      _sendMessage(_messageController.text);
                    }
                  },
                  child: Text('Enviar'),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () {
                      if (_scanResult.isNotEmpty) {
                        _sendMessage('OFAN');
                      }
                    },
                    child: Text('ON'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      if (_scanResult.isNotEmpty) {
                        _sendMessage('OFAO');
                      }
                    },
                    child: Text('OFF'),
                  ),
                ),
              ],
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

class CenasPage extends StatefulWidget {
  @override
  _CenasPageState createState() => _CenasPageState();
}

class _CenasPageState extends State<CenasPage> {
  final TextEditingController _cenaController = TextEditingController();
  List<bool> _checkBoxValuesGreen = List.generate(8, (index) => false);
  List<bool> _checkBoxValuesRed = List.generate(8, (index) => false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cenas Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cenaController,
                    decoration: InputDecoration(
                      labelText: 'Cena',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.content_copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _cenaController.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cena copiada para a área de transferência')),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 10), // Espaçamento entre o TextField e o texto "Placa 1"
            Text(
              'Placa 1',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10), // Espaçamento entre o texto "Placa 1" e as ChoiceChips
            Column(
              children: List.generate(8, (index) {
                return Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _checkBoxValuesGreen[index] = !_checkBoxValuesGreen[index];
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.all(4),
                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                          decoration: BoxDecoration(
                            color: _checkBoxValuesGreen[index] ? Colors.green : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'C${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _checkBoxValuesGreen[index] ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10), // Espaçamento entre as colunas
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _checkBoxValuesRed[index] = !_checkBoxValuesRed[index];
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.all(2),
                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                          decoration: BoxDecoration(
                            color: _checkBoxValuesRed[index] ? Colors.red : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'C${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _checkBoxValuesRed[index] ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ElevatedButton(
                  onPressed: () {
                    // Lógica para gerar a cena
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cena gerada')),
                    );
                  },
                  child: Text('Gerar Cena'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
