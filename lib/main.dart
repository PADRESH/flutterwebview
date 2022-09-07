import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:android_path_provider/android_path_provider.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';

class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
  HttpOverrides.global = DevHttpOverrides();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late String _downloadPath;
  ReceivePort port = ReceivePort();

  @override
  void initState() {
    super.initState();
    IsolateNameServer.registerPortWithName(port.sendPort, "downloads");
    port.listen((message) {
      String id = message[0];
      FlutterDownloader.loadTasksWithRawQuery(query: "SELECT * FROM task WHERE task_id='$id'").then((taskList) => {
        if (taskList != null && taskList.isNotEmpty) {
          extractArchive(taskList.first)
        }
      });
    });
    FlutterDownloader.registerCallback(downloadCallback, step: 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      asyncInitState();
    });
  }

  Future<void> asyncInitState() async {
    _downloadPath = (await getDownloadPath())!;
    final savedDir = Directory(_downloadPath + "/zips");
    final hasExisted = savedDir.existsSync();
    if (!hasExisted) {
      await savedDir.create();
    }
    var fileList = savedDir.listSync();
    for (var element in fileList) {
      print('size: ${element.statSync().size}, name: ${element.path}');
      element.deleteSync(recursive: true);
    }
    fileList = savedDir.listSync();
    if (fileList.isEmpty) {
      downloadArchive("https://10.0.2.2:3000/nick", savedDir.path, "nick.zip");
    }
  }

  Future<void> extractArchive(DownloadTask task) async {
    String _documentsPath = (await getDocumentsPath())!;
    print('extracting url: ${task.url}, filename: ${task.filename}, savedDir: ${task.savedDir}, ');
    final zipDir = Directory(task.url);

  }

  @pragma('vm:entry-point')
  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    // download finished
    if (status.value == 3) {
      final SendPort? sender = IsolateNameServer.lookupPortByName('downloads');
      // notify
      sender?.send([id, status, progress]);
    }
  }

  Future<String?> downloadArchive(String url, String dir, String file) async {
    return await FlutterDownloader.enqueue(
      url: url,
      savedDir: dir,
      showNotification: false,
      fileName: file,
      openFileFromNotification: false, // click on notification to open downloaded file (for Android)
    );
  }

  Future<String?> getDownloadPath() async {
    String? externalStorageDirPath;
    if (Platform.isAndroid) {
      try {
        externalStorageDirPath = await AndroidPathProvider.downloadsPath;
      } catch (e) {
        final directory = await getExternalStorageDirectory();
        externalStorageDirPath = directory?.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath = (await getApplicationSupportDirectory()).absolute.path;
    }
    return externalStorageDirPath;
  }

  Future<String?> getDocumentsPath() async {
    String? externalStorageDirPath;
    if (Platform.isAndroid) {
      try {
        externalStorageDirPath = await AndroidPathProvider.documentsPath;
      } catch (e) {
        final directory = await getExternalStorageDirectory();
        externalStorageDirPath = directory?.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath = (await getApplicationDocumentsDirectory()).absolute.path;
    }
    return externalStorageDirPath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: const WebviewScaffold(
          url: 'https://10.0.2.2:3000',
          ignoreSSLErrors: true,
        ));
  }
}
