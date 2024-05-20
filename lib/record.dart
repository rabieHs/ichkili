import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:ripple_wave/ripple_wave.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  String _healthIssue = '';
  bool _isRecording = false;
  String _filePath = '';
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _record = AudioRecorder();

  @override
  void dispose() {
    _record.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        setState(() {
          _audioPlayer.stop();
        });
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _record.hasPermission()) {
        Directory tempDir = await getTemporaryDirectory();
        _filePath = '${tempDir.path}/recording.wav';

        await _record.start(
            path: _filePath,
            RecordConfig(
              encoder: AudioEncoder.wav,
            ));

        setState(() {
          _isRecording = true;
        });
      } else {
        print('Recording permission not granted.');
      }
    } catch (e) {
      print('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _record.stop();

      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      print('Failed to stop recording: $e');
    }
  }

  Future<void> _playRecording() async {
    if (_filePath.isEmpty || !File(_filePath).existsSync()) {
      print('File not found: $_filePath');
      return;
    }

    try {
      await _audioPlayer.play(DeviceFileSource(_filePath));
    } catch (e) {
      print('Failed to play recording: $e');
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      print('Failed to pause recording: $e');
    }
  }

  void _removeRecording() {
    setState(() {
      _filePath = '';
    });
  }

  Future<void> _analyzeVoice() async {
    if (_filePath.isEmpty || !File(_filePath).existsSync()) {
      setState(() {
        _healthIssue = 'No recording found';
      });
      return;
    }

    setState(() {
      _healthIssue = 'Analyzing...';
    });

    try {
      // Stop recording before sending the request
      await _stopRecording();

      var url = Uri.parse('http://192.168.1.27:4000/predict');
      var request = http.MultipartRequest('POST', url);
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          _filePath,
        ),
      );

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        var data = jsonDecode(responseBody);
        setState(() {
          _healthIssue = data['predicted_issue'];
        });

        await FirebaseFirestore.instance.collection('issues').add({
          'uid': FirebaseAuth.instance.currentUser!.uid,
          'issue_name': _healthIssue,
          'timestamp': DateTime.now(),
        });
      } else {
        var responseBody = await response.stream.bytesToString();
        print(
            'Failed to analyze voice: ${response.statusCode} - $responseBody');
        setState(() {
          _healthIssue = 'Failed to analyze voice';
        });
      }
    } catch (e) {
      print('Failed to analyze voice: $e');
      setState(() {
        _healthIssue = 'Failed to analyze voice: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              _startRecording();
            },
            child: _isRecording
                ? SizedBox(
                    height: 250,
                    width: 250,
                    child: RippleWave(
                      child: Icon(Icons.mic_rounded),
                    ),
                  )
                : CircleAvatar(
                    radius: 60,
                    child: Icon(Icons.mic_rounded, size: 30),
                  ),
          ),
          SizedBox(height: 20),
          !_isRecording ? Text("Long press to start recording") : SizedBox(),
          SizedBox(height: 20),
          _filePath.isNotEmpty
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _audioPlayer.state == PlayerState.playing
                          ? _pauseRecording
                          : _playRecording,
                      child: _audioPlayer.state == PlayerState.playing
                          ? Icon(Icons.pause)
                          : Icon(Icons.play_arrow),
                    ),
                    SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: _removeRecording,
                      child: Icon(Icons.delete),
                    ),
                  ],
                )
              : SizedBox(),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  _analyzeVoice();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stop),
                    Text('Stop and Analyze'),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _healthIssue != ''
              ? FutureBuilder(
                  future: FirebaseFirestore.instance
                      .collection("solutions")
                      .doc(_healthIssue)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text("Error"),
                      );
                    }
                    if (snapshot.data == null) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    } else {
                      Map<String, dynamic> solutions = snapshot.data!.data()!;

                      List solutionsList = solutions["solution"];

                      return ListView.builder(
                          itemCount: solutionsList.length,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text("Solution ${index + 1}"),
                              subtitle: Text(solutionsList[index]),
                              leading: Text((index + 1).toString()),
                            );
                          });
                    }
                  })
              : Text(_healthIssue)
        ],
      ),
    );
  }
}
