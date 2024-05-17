import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HostoryState();
}

class _HostoryState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User History'),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('issues').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var issue = snapshot.data!.docs[index];
              return ListTile(
                title: Text(issue['issue_name']),
                subtitle: Text(
                  'Date: ${issue['timestamp'].toDate().toString()}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
