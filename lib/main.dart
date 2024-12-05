// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs
// https://gist.github.com/blehr/d39288ca9640de7a98b02d9d0b49395 - accelerometer
// https://pub.dev/packages/sensors_plus
// https://developer.android.com/reference/android/hardware/SensorManager

import 'dart:async';
import 'dart:io';
import "dart:core";
import "dart:math";

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:intl/intl.dart';
import "package:path_provider/path_provider.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:gps_tracker/gps_tracker.dart";

import "upload_window.dart";
import "utils.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensors Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
   with WidgetsBindingObserver {
  final double G = 9.8;
  List<double>? _userAccelerometerValues;
  List<double>? _accelerometerValues;
  List<double>? _gyroscopeValues;
  List<double>? _magnetometerValues;
  double        _cumUserDistance  = 0.0;
  double        _cumAccelDistance = 0.0;
  double        _cumDistance      = 0.0;
  double?       _heading;
  List<double>  _prevVelocity = [0.0, 0.0, 0.0];
  List<double>  _prevPosition = [0.0, 0.0, 0.0];
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  List<List<double>> savedValues = [];
  int SAVE_FREQUENCY = 10;
  int saveInd        = 0;
  bool collecting    = false;
  bool paused        = false;
  String collectingPrompt = "Collect";
  String pausePrompt      = "Pause";
  Widget saveButton       = simpleButton("Save", null);
  late Widget uploadButton;
  late Widget pauseButton;
  double latitude       = 0.0;
  double longitude      = 0.0;
  double _prevLatitude  = 0.0;
  double _prevLongitude = 0.0;
  double speed          = 0.0;

  void _listener(dynamic o) {
    final Map<dynamic,dynamic> map = o as Map;
    final reason = map["reason"];
    if (reason == "COORDINATE_UPDATE") {
      latitude  = map["latitude"]! as double;
      longitude = map["longitude"]! as double;
      speed     = map["speed"]! as double;
    }
  }

  @override
  Future<void> startService() async
  {
    int status = await GpsTracker.getCurrentLocationPermissions();
    if (status != GpsTracker.GRANTED) {
      status = await GpsTracker.requestLocationPermissions();
    }

    try {
      GpsTracker.addGpsListener(_listener);
      await GpsTracker.start(
        title: "Title",
        text: "Text",
        subText: "Subtext",
        ticker: "Ticker",
      );
    } catch (err) {
      showMessage(context, "ERROR", err.toString());
    }
  }

  @override
  Future<void> stopService(var param) async
  {
    GpsTracker.removeGpsListener(_listener);
    GpsTracker.stop();
  }

  void collectingPressed() {
    setState(() {
      if (collecting) {
        collecting       = false;
        collectingPrompt = "Collect";
        saveButton = simpleButton("Save",saveToFile);
        uploadButton = simpleButton("Upload", displayUploadWindow);
      } else {
        savedValues.clear();
        saveInd          = 0;
        collecting       = true;
        collectingPrompt = "Stop";
        saveButton = simpleButton("Save", null);
        uploadButton = simpleButton("Upload", null);
      }
    });
  }

  void pausePressed() {
    setState(() {
      if (paused) {
        paused      = false;
        pausePrompt = "Pause";
      } else {
        paused      = true;
        pausePrompt = "Res";
      }
    });
  }

  static Widget simpleButton(String prompt, void Function()? action) {
    return ElevatedButton(
      onPressed: action,
      child: Text(prompt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAccelerometer = _userAccelerometerValues
        ?.map((double v) => v.toStringAsFixed(1))
        .toList();
    final accelerometer = _accelerometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final gyroscope     = _gyroscopeValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final magnetometer  = _magnetometerValues?.map((double v) => v.toStringAsFixed(1)).toList();
    final heading       = _heading?.toStringAsFixed(2);

    List<double> velocity = [0.0, 0.0, 0.0];
    List<double> position = [0.0, 0.0, 0.0];
    double accelDistance  = 0.0;
    double inclination    = 0.0;
    if (_accelerometerValues != null) {
      inclination = asin(_accelerometerValues![2]/G)*180.0/pi;
      for (int i = 0; i < _prevVelocity.length; i++) {
        velocity[i] = _prevVelocity[i] + _accelerometerValues![i];
        position[i] = _prevPosition[i] + velocity[i];
      }
      accelDistance     = sqrt(pow(position[0], 2) + pow(position[1], 2));
      _cumAccelDistance = accelDistance + _cumAccelDistance!;
      for (int i = 0; i < _prevVelocity.length; i++) {
        _prevVelocity[i] = _accelerometerValues![i];
      }
    }

    double userDistance = 0.0;
    if (_userAccelerometerValues != null) {
      for (int i = 0; i < _prevVelocity.length; i++) {
        velocity[i] = _prevVelocity[i] + _userAccelerometerValues![i];
        position[i] = _prevPosition[i] + velocity[i];
      }
      userDistance = sqrt(pow(position[0], 2) + pow(position[1], 2));
      _cumUserDistance = userDistance + _cumUserDistance!;
      for (int i = 0; i < _prevVelocity.length; i++) {
        _prevVelocity[i] = _userAccelerometerValues![i];
      }
    }

    double distance = 0.0;
    if (_prevLatitude != 0.0 && _prevLongitude != 0.0) {
      if (_prevLatitude != latitude || _prevLongitude != longitude) {
        distance       = calculateDistance(latitude, longitude, _prevLatitude, _prevLongitude);
        _prevLatitude  = latitude;
        _prevLongitude = longitude;
      }
      _cumDistance = distance + _cumDistance;
    } else {
      _prevLatitude  = latitude;
      _prevLongitude = longitude;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Example'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(width: 1.0, color: Colors.black38),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('UserAccelerometer: $userAccelerometer'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('UserDistance: ${userDistance..toInt().toString()}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('CumUserDistance: ${_cumUserDistance!.toInt().toString()}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Accelerometer: $accelerometer'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('AccelDistance: ${accelDistance.toInt().toString()}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('inclination ${inclination.toInt().toString()} CumAccelDistance: ${_cumAccelDistance!.toInt().toString()}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Gyroscope: $gyroscope'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Magnetometer: $magnetometer'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Heading: $heading'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Lat: ${latitude.toStringAsFixed(5)}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Lon: ${longitude.toStringAsFixed(5)}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Speed: ${speed.toStringAsFixed(5)}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Distance: ${distance!.toStringAsFixed(3)}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('CumDistance: ${_cumDistance!.toStringAsFixed(3)}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                ElevatedButton(
                  onPressed: collectingPressed,
                  child: Text(collectingPrompt),
                ),
                saveButton,
                uploadButton,
                ElevatedButton(
                  onPressed: pausePressed,
                  child: Text(pausePrompt),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    startService();
    _streamSubscriptions.add(
      userAccelerometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen(
        (UserAccelerometerEvent event) {
          setState(() {
            _userAccelerometerValues = <double>[event.x, event.y, event.z];
          });
        }
      ),
    );
    // _streamSubscriptions.add(
    //   userAccelerometerEvents.listen(
    //     (UserAccelerometerEvent event) {
    //       setState(() {
    //         _userAccelerometerValues = <double>[event.x, event.y, event.z];
    //       });
    //     },
    //   ),
    // );
    _streamSubscriptions.add(
      accelerometerEvents.listen(
        (AccelerometerEvent event) {
          if (collecting) {
            if (saveInd == 0) {
              savedValues.add(<double>[
                DateTime
                    .now()
                    .millisecondsSinceEpoch
                    .toDouble(),
                event.x,
                event.y,
                event.z,
                latitude,
                longitude,
                speed
              ]);
            }
            saveInd = (saveInd + 1)%SAVE_FREQUENCY;
          }
          if (!paused) {
            setState(() {
              _accelerometerValues = <double>[event.x, event.y, event.z];
            });
          }
        },
      ),
    );
    _streamSubscriptions.add(
      gyroscopeEvents.listen(
            (GyroscopeEvent event) {
              if (!paused) {
                setState(() {
                  _gyroscopeValues = <double>[event.x, event.y, event.z];
                });
              }
        },
      ),
    );
    _streamSubscriptions.add(
      magnetometerEvents.listen(
            (MagnetometerEvent event) {
              if (!paused) {
                setState(() {
                  _magnetometerValues = <double>[event.x, event.y, event.z];
                  _heading = (atan2(event.y, event.x) * 180.0) / pi;
                });
              }
        },
      ),
    );
    uploadButton = simpleButton("Upload", displayUploadWindow);
  }



  // @override
  // void initState() {
  //   super.initState();
  //   _streamSubscriptions.add(
  //     userAccelerometerEventStream(samplingPeriod: sensorInterval).listen(
  //           (UserAccelerometerEvent event) {
  //         final now = DateTime.now();
  //         setState(() {
  //           _userAccelerometerEvent = event;
  //           if (_userAccelerometerUpdateTime != null) {
  //             final interval = now.difference(_userAccelerometerUpdateTime!);
  //             if (interval > _ignoreDuration) {
  //               _userAccelerometerLastInterval = interval.inMilliseconds;
  //             }
  //           }
  //         });
  //         _userAccelerometerUpdateTime = now;
  //       },
  //       onError: (e) {
  //         showDialog(
  //             context: context,
  //             builder: (context) {
  //               return const AlertDialog(
  //                 title: Text("Sensor Not Found"),
  //                 content: Text(
  //                     "It seems that your device doesn't support User Accelerometer Sensor"),
  //               );
  //             });
  //       },
  //       cancelOnError: true,
  //     ),
  //   );
  //   _streamSubscriptions.add(
  //     accelerometerEventStream(samplingPeriod: sensorInterval).listen(
  //           (AccelerometerEvent event) {
  //         final now = DateTime.now();
  //         setState(() {
  //           _accelerometerEvent = event;
  //           if (_accelerometerUpdateTime != null) {
  //             final interval = now.difference(_accelerometerUpdateTime!);
  //             if (interval > _ignoreDuration) {
  //               _accelerometerLastInterval = interval.inMilliseconds;
  //             }
  //           }
  //         });
  //         _accelerometerUpdateTime = now;
  //       },
  //       onError: (e) {
  //         showDialog(
  //             context: context,
  //             builder: (context) {
  //               return const AlertDialog(
  //                 title: Text("Sensor Not Found"),
  //                 content: Text(
  //                     "It seems that your device doesn't support Accelerometer Sensor"),
  //               );
  //             });
  //       },
  //       cancelOnError: true,
  //     ),
  //   );
  //   _streamSubscriptions.add(
  //     gyroscopeEventStream(samplingPeriod: sensorInterval).listen(
  //           (GyroscopeEvent event) {
  //         final now = DateTime.now();
  //         setState(() {
  //           _gyroscopeEvent = event;
  //           if (_gyroscopeUpdateTime != null) {
  //             final interval = now.difference(_gyroscopeUpdateTime!);
  //             if (interval > _ignoreDuration) {
  //               _gyroscopeLastInterval = interval.inMilliseconds;
  //             }
  //           }
  //         });
  //         _gyroscopeUpdateTime = now;
  //       },
  //       onError: (e) {
  //         showDialog(
  //             context: context,
  //             builder: (context) {
  //               return const AlertDialog(
  //                 title: Text("Sensor Not Found"),
  //                 content: Text(
  //                     "It seems that your device doesn't support Gyroscope Sensor"),
  //               );
  //             });
  //       },
  //       cancelOnError: true,
  //     ),
  //   );
  //   _streamSubscriptions.add(
  //     magnetometerEventStream(samplingPeriod: sensorInterval).listen(
  //           (MagnetometerEvent event) {
  //         final now = DateTime.now();
  //         setState(() {
  //           _magnetometerEvent = event;
  //           if (_magnetometerUpdateTime != null) {
  //             final interval = now.difference(_magnetometerUpdateTime!);
  //             if (interval > _ignoreDuration) {
  //               _magnetometerLastInterval = interval.inMilliseconds;
  //             }
  //           }
  //         });
  //         _magnetometerUpdateTime = now;
  //       },
  //       onError: (e) {
  //         showDialog(
  //             context: context,
  //             builder: (context) {
  //               return const AlertDialog(
  //                 title: Text("Sensor Not Found"),
  //                 content: Text(
  //                     "It seems that your device doesn't support Magnetometer Sensor"),
  //               );
  //             });
  //       },
  //       cancelOnError: true,
  //     ),
  //   );
  // }





  void saveToFile() async {
    // String fileName = Uuid().v1() + ".json"; // Generate a v1 (time-based) id
    final DateTime now    = DateTime.now();
    final String suggestedFileName = "${DateFormat("yyyy-MM-dd_HH:mm:ss").format(now)}";
    if (suggestedFileName.isEmpty) {
      return;
    }

    String fileName = await getFilenameDialog(suggestedFileName);
    fileName        = "$fileName.json";
    String path     = "";

    if (Platform.isAndroid) {
      final Directory? a = await getExternalStorageDirectory(); // OR return "/storage/emulated/0/Download";
      final String androidPath = a!.path;
      path = androidPath + Platform.pathSeparator + fileName;
    } else if (Platform.isIOS) {
      final Directory d = await getApplicationDocumentsDirectory();
      path = d.path + Platform.pathSeparator + fileName;
    }
    File f = File(path);

    String json = "[";
    for (int i = 0; i < savedValues.length - 1; i++) {
      json = '$json${readingToJson(savedValues[i])},';
    }
    json = '$json${readingToJson(savedValues[savedValues.length - 1])}]';

    f.writeAsStringSync(json);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? files = prefs.getStringList("savedFiles");
    if (files == null) {
      files = [];
    }
    files.add(fileName);
    await prefs.setStringList("savedFiles",files);

    showMessage(context, "INFORMATION", "Data saved successfully");

// Writing:
// 1) Retrieve the list of strings
// 2) Add the new one to the list

// Reading:
// Retrieve the list of strings
// Display to user allowing for upload
// Provide a means to rename/delete the files
// Rewrite the list when modified
// Delete the files which are no longer wanted


//    await prefs.setStringList('items', <String>['Earth', 'Moon', 'Sun']);

    //  final SharedPreferences prefs = await SharedPreferences.getInstance();
    //  filename  = prefs.getString("filename");
    //  File f = File(path);
    //  String json = f.readAsStringSync();
    // //var jsonResponse = json.decode(contents);
    //  String json = '{ "$title","${DateFormat("dd-MM-yyyy HH:mm:ss").format(
    //  DateTime.now())}",$jsonResponse}';

  }

  Future<String> getFilenameDialog(String name) async {
    final nameController = TextEditingController(text: name);

    String data = await showDialog(
        barrierDismissible: false, // user must tap button!
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Name"),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              //position
              mainAxisSize: MainAxisSize.min,
              // wrap content in flutter
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Name",
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () async {
                    try {
                      if (nameController.text.isEmpty || nameController.text.trim().isEmpty) {
                        throw Exception("Invalid name");
                      }
                      Navigator.pop(context, nameController.text);
                    } catch (err) {
                      showMessage(context, "ERROR", err.toString());
                    }
                  },
                  child: const Text("Save")),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, null);
                },
                child: const Text("Cancel"),
              )
            ],
          );
        });
    return data;
  }

  void displayUploadWindow() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (BuildContext context) => UploadWindow()),
    );
  }

  double calculateDistance(lat1, lon1, lat2, lon2)
  {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p)/2 +
        cos(lat1 * p) * cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a));
  }
}
