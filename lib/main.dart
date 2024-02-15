
import 'package:cache_poc/dashboard.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routes: {
        '/': (context) => const MyHomePage(title: 'Flutter Demo Home Page'),
        '/dashboard': (context) => const DashboardPage(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final url = 'https://iradar.tech/account/get_token_pair/';
  final storage = FlutterSecureStorage();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  Widget _signIn(){
    return MaterialButton(
        child: Text("Sign In"),
        onPressed: () async{
          final dio = Dio();
          try {
            final response = await dio.post(
              url,
              data: {
                "email": emailController.text,
                "password": passwordController.text,
              },
              options: Options(
                contentType: Headers.jsonContentType,
              ),
            );
            final data = response.data;
            if (response.statusCode == 200 && data["access"] != null) {
              storage.write(
                  key: 'access_key',
                  value: data["access"]);
              storage.write(
                  key: 'refresh_key',
                  value: data["refresh"]);
              Navigator.pushReplacementNamed(context, '/dashboard');
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("$e"),
                )
            );
          }
        }
    );
  }

  Widget _form(){
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 50),
      child: Column(
        children: [
          TextField(
            controller: emailController,
            decoration: InputDecoration(
              labelText: "Email",
            ),
          ),
          TextField(
            obscureText: true,
            controller: passwordController,
            decoration: InputDecoration(
              labelText: "Password",
            ),
          ),
          _signIn(),
        ],
      ),
    );
  }

  void _refreshTokens() async{
    final urlToken = 'https://iradar.tech/account/token/refresh/';
    final dio = Dio();
    var storage = const FlutterSecureStorage();
    var access = await storage.read(key: 'access_key');
    var refresh = await storage.read(key: 'refresh_key');
    if (JwtDecoder.isExpired(access!)){
      //Clear local storage if tokens have expired
      if (JwtDecoder.isExpired(refresh!)){
        storage.deleteAll();
      }
      //Refreshing the tokens
      else{
        final response = await dio.post(urlToken, data: {"refresh": refresh});
        final newTokens = response.data;
        access = newTokens['access'];
        refresh = newTokens['refresh'];
        await storage.write(key: 'access_key', value: access);
        await storage.write(key: 'refresh_key', value: refresh);
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    }
    else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshTokens();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: _form(),
      ),
    );
  }
}
