import 'package:flutter/material.dart';
import 'package:ichkili/history.dart';
import 'package:ichkili/record.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  List<Widget> screens = [
    RecordScreen(),
    HistoryScreen(),
  ];
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (value) {
          setState(() {
            index = value;
          });
        },
        items: [
          BottomNavigationBarItem(
              icon: Icon(Icons.record_voice_over), label: "Test"),
          BottomNavigationBarItem(
              icon: Icon(Icons.history_sharp), label: "History")
        ],
      ),
      body: screens[index],
    );
  }
}
