import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:path_provider/path_provider.dart';

import 'interceptors.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List stations = [];
  late Dio dio;
  String info = '';
  late StreamSubscription subscription;
  bool isDeviceConnected = false;

  void _refreshTokens() async{
    const urlToken = 'https://iradar.tech/account/token/refresh/';
    var storage = const FlutterSecureStorage();
    var access = await storage.read(key: 'access_key');
    var refresh = await storage.read(key: 'refresh_key');
    //Clear local storage if tokens have expired
    if (JwtDecoder.isExpired(refresh!)){
      storage.deleteAll();
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
    //Refreshing the tokens
    else{
      final response = await dio.post(urlToken, data: {"refresh": refresh});
      final newTokens = response.data;
      access = newTokens['access'];
      refresh = newTokens['refresh'];
      await storage.write(key: 'access_key', value: access);
      await storage.write(key: 'refresh_key', value: refresh);
    }
  }

  void _cacheTest() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/post_request_cache.json');
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final jsonData = jsonDecode(contents);
        final response = await dio.post(jsonData["url"], data: jsonData["data"]);
        final newTokens = response.data;
        var storage = const FlutterSecureStorage();
        var access = newTokens['access'];
        var refresh = newTokens['refresh'];
        await storage.write(key: 'access_key', value: access);
        await storage.write(key: 'refresh_key', value: refresh);
        print("Refresh Token $refresh");
      }
    } catch (e) {
      print('Error loading cached requests: $e');
    }
  }

  Future<void> loadCachedStations() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/station_cache.json');
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final List<dynamic> cachedStations = jsonDecode(contents);
        setState(() {
          stations = List.from(cachedStations);
        });
      }
    } catch (e) {
      print('Error loading cached stations: $e');
    }
  }


  // Retrieve a list of stations from the backend
  Future<void> _getStations() async {
    var storage = const FlutterSecureStorage();
    var access = await storage.read(key: 'access_key');
    try {
      await loadCachedStations();
      const url = 'https://iradar.tech/station/api/active/list/?all=1';
      var response = await dio.get(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $access'},
        ),
      );
      if (response.statusCode == 200) {
        var stationList = response.data;
        setState(() {
          stations = List.from(stationList);
        });
      } else {
        print(response.statusCode);
      }
    } catch (error) {
      print(error);
    }
  }

  @override
  void initState() {
    subscription = Connectivity().onConnectivityChanged.listen(
          (ConnectivityResult result) async {
        isDeviceConnected = await InternetConnectionChecker().hasConnection;
        if (isDeviceConnected) {
          print("Internet connected");
          _cacheTest();
        }
        else {
          print("Internet disconnected");
        }
      },
    );
    super.initState();
    dio = Dio();
    dio.interceptors.add(CacheInterceptor());
    _getStations();
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  Widget _pendingButton(){
    return MaterialButton(
      color: Colors.blue,
      child: Text("Pending",
        style: TextStyle(
          color: Colors.white
        ),
      ),
      onPressed: () async {
        _refreshTokens();
      },
    );
  }
  Widget _cache(){
    return MaterialButton(
      color: Colors.blue,
      child: Text("Cache",
        style: TextStyle(
            color: Colors.white
        ),
      ),
      onPressed: () async {
        _cacheTest();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Dashboard"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _pendingButton(),
              Text("$stations")
            ],
          )
        )
      ),
    );
  }
}
