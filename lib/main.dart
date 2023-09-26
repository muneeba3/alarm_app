import 'dart:core';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones(); // Initialize time zones
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Alarm app'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Alarm> alarms = [];

  @override
  void initState() {
    super.initState();
    _getAlarms().then((alarmList) {
      setState(() {
        alarms = alarmList;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: Text(widget.title, style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SetAlarm(),
                ),
              ).then((newAlarm) {
                if (newAlarm != null) {
                  setState(() {
                    alarms.add(newAlarm);
                  });
                }
              });
            },
            icon: Icon(Icons.add, color: Colors.white),
          )
        ],
      ),
      body: alarms.isEmpty
          ? const Center(
        child: Text('No alarms set yet'),
      )
          : ListView.builder(
        itemCount: alarms.length,
        itemBuilder: (context, index) {
          final alarm = alarms[index];
          final timeUntilAlarm = _calculateTimeUntilAlarm(alarm.time);
          return ListTile(
            title: Text(alarm.time.format(context)),
            subtitle: Text(
              'Ring in: ${timeUntilAlarm.inHours} hours , ${timeUntilAlarm.inMinutes.remainder(60)} minutes and ${timeUntilAlarm.inSeconds.remainder(60)} seconds',
            ),
            trailing: Switch(
              value: alarm.isEnabled,
              onChanged: (value) {
                _toggleAlarm(alarm, value); // Call _toggleAlarm method
              },
            ),
          );

        },
      ),
    );
  }

  Future<void> _toggleAlarm(Alarm alarm, bool isEnabled) async {
    setState(() {
      alarm.isEnabled = isEnabled;
    });

    await _saveAlarms(); // Save the updated list of alarms
  }


  Future<void> _saveAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmStrings = alarms.map((alarm) => alarm.toJson()).toList();
    await prefs.setStringList('alarms', alarmStrings.cast<String>());
  }

  Future<List<Alarm>> _getAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmStrings = prefs.getStringList('alarms');
    if (alarmStrings == null || alarmStrings.isEmpty) {
      return [];
    }

    return alarmStrings.map((alarmString) {
      final alarmJson = Alarm.fromJson(alarmString as Map<String, dynamic>);
      return alarmJson;
    }).toList();
  }

  Duration _calculateTimeUntilAlarm(TimeOfDay alarmTime) {
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      alarmTime.hour,
      alarmTime.minute,
    );

    return selectedDateTime.isBefore(now)
        ? selectedDateTime.add(Duration(days: 1)).difference(now)
        : selectedDateTime.difference(now);
  }
}

class SetAlarm extends StatefulWidget {
  const SetAlarm({Key? key});

  @override
  State<SetAlarm> createState() => _SetAlarmState();
}

class _SetAlarmState extends State<SetAlarm> {
  TimeOfDay selectedTime = TimeOfDay.now(); // Store the selected time
  String selectedAlarmTone = 'Default Tone'; // Store the selected alarm tone
  bool isAlarmEnabled = true; // Store whether the alarm is enabled or disabled
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _initializeLocalNotifications();
  }
  Duration _calculateTimeUntilAlarm(TimeOfDay alarmTime) {
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      alarmTime.hour,
      alarmTime.minute,
    );

    return selectedDateTime.isBefore(now)
        ? selectedDateTime.add(Duration(days: 1)).difference(now)
        : selectedDateTime.difference(now);
  }

  void _showAlarmTimeToast() async {
    if (isAlarmEnabled) {
      final timeUntilAlarm = _calculateTimeUntilAlarm(selectedTime);

      Fluttertoast.showToast(
        msg: 'Alarm set for ${selectedTime.format(context)}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 5,
        backgroundColor: Colors.indigo,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      // Schedule the alarm notification
      await _scheduleAlarmNotification(timeUntilAlarm);
    }
  }


  Future<void> _initializeLocalNotifications() async {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: null,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (pickedTime != null && pickedTime != selectedTime) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Alarm', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                _selectTime(context);
              },
              child: Row(
                children: [
                  const Text(
                    'Select Alarm time:',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    selectedTime.format(context),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20.0),
            Row(
              children: [
                const Text(
                  'Select Alarm tone:  ',
                  style: TextStyle(fontSize: 18),
                ),
                DropdownButton<String>(
                  value: selectedAlarmTone,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedAlarmTone = newValue!;
                    });
                  },
                  dropdownColor: Colors.indigo,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: 'Default Tone',
                      child: Text('Default Tone'),
                    ),
                    DropdownMenuItem(
                      value: 'Tone 1',
                      child: Text('Tone 1'),
                    ),
                    DropdownMenuItem(
                      value: 'Tone 2',
                      child: Text('Tone 2'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20.0),
            Row(
              children: [
                const Text(
                  'Enable Alarm:',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8.0),
                Switch(
                  value: isAlarmEnabled,
                  onChanged: (bool newValue) {
                    setState(() {
                      isAlarmEnabled = newValue;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor:
                MaterialStateProperty.all<Color?>(Colors.indigo),
              ),
              onPressed: () {
                _saveAlarm();
              },
              child: const Text(
                'Save Alarm',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAlarm() async {
    final alarm = Alarm(
      time: selectedTime,
      tone: selectedAlarmTone,
      isEnabled: isAlarmEnabled,
    );
    _showAlarmTimeToast();

    Navigator.pop(context, alarm);
  }

  Future<void> _scheduleAlarmNotification(Duration timeUntilAlarm) async {
    final String timeZoneName = tz.local.name;

    final tz.TZDateTime scheduledTime =
    tz.TZDateTime.now(tz.getLocation(timeZoneName)).add(timeUntilAlarm);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'alarm_channel_id',
      'Alarm Notification',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Alarm',
      'It\'s time for your alarm!',
      scheduledTime,
      platformChannelSpecifics,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

class Alarm {
  final TimeOfDay time;
  final String tone;
  bool isEnabled;

  Alarm({
    required this.time,
    required this.tone,
    required this.isEnabled,
  });

  Map<String, dynamic> toJson() {
    return {
      'hour': time.hour,
      'minute': time.minute,
      'tone': tone,
      'isEnabled': isEnabled,
    };
  }

  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      time: TimeOfDay(
        hour: json['hour'],
        minute: json['minute'],
      ),
      tone: json['tone'],
      isEnabled: json['isEnabled'],
    );
  }
}
