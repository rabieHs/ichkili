import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ichkili/firebase_options.dart';
import 'package:ichkili/home.dart';
import 'package:ichkili/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? isVerified;

  @override
  void initState() {
    // TODO: implement initStat
    FirebaseFirestore.instance.collection("auth").doc("1").get().then((value) {
      final data = value.data();
      isVerified = data!["verified"];
      setState(() {});
    });
    super.initState();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: isVerified == true
          ? FirebaseAuth.instance.currentUser == null
              ? LoginPage()
              : HomeScreen()
          : isVerified == null
              ? Center()
              : Center(
                  child: Text("Your App is locked"),
                ),
    );
  }
}
