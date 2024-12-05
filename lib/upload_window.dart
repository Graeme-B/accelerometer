import "dart:async";
import "dart:io";
import "dart:convert" show utf8;

import "dart:core";

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import "package:path_provider/path_provider.dart";
import "package:shared_preferences/shared_preferences.dart";

import "utils.dart";

class UploadWindow extends StatefulWidget {
  const UploadWindow({Key? key,}) : super(key: key);
  @override
  State<UploadWindow> createState() => _UploadWindowState();
}

class _UploadWindowState extends State<UploadWindow> {

  _UploadWindowState();
  List<String> items          = [];
  var selectedItem            = 0;

  @override
  @protected
  void initState() {
    super.initState();
    repopulateList();
  }

  Future<void> repopulateList() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? files = prefs.getStringList("savedFiles");

    items = [];
    if (files != null) {
      for (String f in files) {
        items.add(f);
      }
    }
    setState(() {
      selectedItem = 0;
    });
  }

  Future<bool> _onBackPressed() {
    return Future(() => true);
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return WillPopScope(
      onWillPop: _onBackPressed,
      child:
      Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: const Text("Available Files"),
        ),
        body:
        Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    var bgColor = Colors.transparent;
                    if (index == selectedItem) {
                      bgColor = Colors.blue;
                    }
                    return Container(
                      decoration: BoxDecoration(color: bgColor),
                      height: 50,
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            selectedItem = index;
                          });
                        },
                        title: Text(items[index]),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, // use whichever suits your need
                children: <Widget>[
                  ElevatedButton(
                    onPressed: items.isNotEmpty ? () {
                      // Navigator.of(context, rootNavigator: true).pop(
                      //     (items.isNotEmpty && selectedItem < items.length) ? items[selectedItem] : "");
                      if (items.isNotEmpty && selectedItem < items.length) {
                        uploadDialog(items[selectedItem]);
                      }
                    } : null,
                    child: const Text("Upload"),
                  ),
                  ElevatedButton(
                    onPressed: items.isNotEmpty ? () {
                      if (items.isNotEmpty && selectedItem < items.length) {
                        renameDialog();
                      }
                    } : null,
                    child: const Text("Rename"),
                  ),
                  ElevatedButton(
                    onPressed: items.isNotEmpty ? () async {
                      if (items.isNotEmpty && selectedItem < items.length) {
                        final String result = await yesNoDialog(
                            "Are you sure you want to delete this item?");
                        if (result == "yes") {
                          await deleteItem(items[selectedItem]);
                        }
                        repopulateList();
                      }
                    } : null,
                    child: const Text("Delete"),
                  ),
                ],
              ),
              const SizedBox( //Use of SizedBox
                height: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void renameDialog() {
    final nameController = TextEditingController(text: items[selectedItem]);

    showDialog(
        barrierDismissible: false, // user must tap button!
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Rename"),
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
// 1) Item name must be unique
// 2) Item name must not be blank
                    try {
                      if (nameController.text.isEmpty || nameController.text.trim().isEmpty) {
                        throw Exception("Invalid name");
                      }
                      await renameItem(items[selectedItem], nameController.text);
                      repopulateList();
                      _dismissDialog();
                    } catch (err) {
                      showErrorMessage(err.toString());
                    }
                  },
                  child: const Text("Rename")),
              TextButton(
                onPressed: () {
                  _dismissDialog();
                },
                child: const Text("Cancel"),
              )
            ],
          );
        });
  }

  void _dismissDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> showErrorMessage(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("ERROR"),
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

  Future<String> yesNoDialog(String message) async {
    final String val = await showDialog(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("INFORMATION"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Yes"),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop("yes");
              },
            ),
            TextButton(
              child: const Text("No"),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop("no");
              },
            ),
          ],
        );
      },
    );
    return val;
  }

  Future<void> deleteItem(String itemName) async {
    String localPath = "";
    if (Platform.isAndroid) {
      final Directory? a = await getExternalStorageDirectory();  // OR return "/storage/emulated/0/Download";
      localPath = a!.path  + Platform.pathSeparator;
    } else if (Platform.isIOS) {
      final Directory d = await getApplicationDocumentsDirectory();
      localPath = d.path;
    }

    File f = File(localPath + Platform.pathSeparator + itemName);
    try {
      if (await f.exists()) {
        await f.delete();
      }

      // final dir = Directory(localPath);
      // final List<FileSystemEntity> entities = await dir.list().toList();
      // for (FileSystemEntity entity in entities) {
      //   print("File ${entity.path}");
      // }

      items.removeWhere((item) => item == itemName);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList("savedFiles",items);

    } catch (e) {
      // Error in getting access to the file.
    }
  }

  Future<void> renameItem(String currentItemName, String newItemName) async {
    String localPath = "";
    if (Platform.isAndroid) {
      final Directory? a = await getExternalStorageDirectory();  // OR return "/storage/emulated/0/Download";
      localPath = a!.path  + Platform.pathSeparator;
    } else if (Platform.isIOS) {
      final Directory d = await getApplicationDocumentsDirectory();
      localPath = d.path;
    }

    File f = File(localPath + Platform.pathSeparator + currentItemName);
    try {
      if (await f.exists()) {
        await f.rename(localPath + Platform.pathSeparator + newItemName);
      }

      final dir = Directory(localPath);
      final List<FileSystemEntity> entities = await dir.list().toList();
      for (FileSystemEntity entity in entities) {
        print("File ${entity.path}");
      }

      items[items.indexWhere((item) => item == currentItemName)] = newItemName;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList("savedFiles",items);

    } catch (e) {
      // Error in getting access to the file.
    }
  }

  void uploadDialog(String item) {
    final nameController = TextEditingController(text: item);

    showDialog(
        barrierDismissible: false, // user must tap button!
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Upload"),
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
                    labelText: "Upload Name",
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () async {
// 1) Walk name must be unique
// 2) Walk name must not be blank
                    try {
                      if (nameController.text.isEmpty || nameController.text.trim().isEmpty) {
                        throw Exception("Invalid Name");
                      }
                      UploadResults result = await uploadValues(nameController.text);
                      await showMessage(context,"INFORMATION", "Uploaded" );
                      _dismissDialog();
                    } catch (err) {
                      showMessage(context, "ERROR", err.toString());
                    }
                  },
                  child: const Text("Upload")),
              TextButton(
                onPressed: () {
                  _dismissDialog();
                },
                child: const Text("Cancel"),
              )
            ],
          );
        });
  }

  // For HTTPS:
  // https://mtabishk999.medium.com/tls-ssl-connection-using-self-signed-certificates-with-dart-and-flutter-6e7c46ea1a36
  Future<UploadResults> uploadValues(String fileName) async {
    late UploadResults results;
    String path = "";

    if (Platform.isAndroid) {
      final Directory? a = await getExternalStorageDirectory(); // OR return "/storage/emulated/0/Download";
      final String androidPath = a!.path;
      path = androidPath + Platform.pathSeparator + fileName;
    } else if (Platform.isIOS) {
      final Directory d = await getApplicationDocumentsDirectory();
      path = d.path + Platform.pathSeparator + fileName;
    }
    File f = File(path);
    String json = f.readAsStringSync();
    json = '{ "fileName": "$fileName","DateTime":"${DateFormat("dd-MM-yyyy HH:mm:ss").format(DateTime.now())}","Data":$json}';

    const String url                = "http://wamm.me.uk/accelerometer/accelerometer_upload.php";
    final HttpClient httpClient     = HttpClient();
    final HttpClientRequest request = await httpClient.postUrl(Uri.parse(url));
    request.headers.set('content-type', 'application/json; charset="UTF-8"');
    request.write(utf8.encode(json));
    final HttpClientResponse response = await request.close();
    int status = response.statusCode;
    final String reply = await response.transform(utf8.decoder).join();
    results = UploadResults(status,reply);
    httpClient.close();

    return results;
  }

}

class UploadResults {
  UploadResults(this.status,this.message);
  int status;
  String? message;
}
