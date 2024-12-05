import "dart:core";

import 'package:flutter/material.dart';

String readingToJson(List<double> reading) {
  String json = '{ "Msec": ${reading[0].toStringAsFixed(0)},';
  json = json + '"x": ${reading[1].toStringAsFixed(4)},';
  json = json + '"y": ${reading[2].toStringAsFixed(4)},';
  json = json + '"z": ${reading[3].toStringAsFixed(4)},';
  json = json + '"lat": ${reading[4].toStringAsFixed(6)},';
  json = json + '"lon": ${reading[5].toStringAsFixed(6)},';
  json = json + '"speed": ${reading[6].toStringAsFixed(3)}}';

  // for (int j = 0; j < reading.length - 1; j++) {
  //   json = '$json"${reading[j].toStringAsFixed(4)}",';
  // }
  // json = '$json"${reading[reading.length - 1].toStringAsFixed(4)}"}';
  return json;
}

Future<void> showMessage(BuildContext context, String title, String message) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(message),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text("OK"),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
        ],
      );
    },
  );
}

