import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        //create a temprary file to save the recording
        Directory tempDir = await getTemporaryDirectory();
        _filePath = '${tempDir.path}/recording.wav';
        setState(() {});
        print(_filePath);

        //start recording
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

  Future<String> _stopRecording() async {
    try {
      final uri = await _record.stop();
      print("stop record with uri $uri");
      setState(() {
        _isRecording = false;
      });
      return uri!;
    } catch (e) {
      print('Failed to stop recording: $e');
      return "";
    }
  }

  Future<void> _playRecording() async {
    if (_filePath.isEmpty || !File(_filePath).existsSync()) {
      print('File not found: $_filePath');
      return;
    }

    try {
      print("starting playin ...");
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

  Future<void> analyzeVoice() async {
    if (_isRecording) {
      _stopRecording();
    }
    print("printing file path: $_filePath");

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
      final request = http.MultipartRequest(
          'POST', Uri.parse("http://10.0.2.2:4000/predict"));
      request.files.add(await http.MultipartFile.fromPath("file", _filePath));
      print("sending request, $request");
      var response = await request.send();

      print(response.statusCode);
      // if the server response was worked successfully!
      if (response.statusCode == 200) {
        //save the server response in _halthIssue variable

        var responseBody = await response.stream.bytesToString();
        var data = jsonDecode(responseBody);
        setState(() {
          _healthIssue = data['prediction'];
        });

        //save the data in the firebase firestore
        await FirebaseFirestore.instance.collection('issues').add({
          'issue_name': _healthIssue,
          'timestamp': DateTime.now(),
        });
      } else {
        // if the server response has an error
        var responseBody = await response.stream.bytesToString();
        print(
            'Failed to analyze voice: ${response.statusCode} - $responseBody');
        setState(() {
          _healthIssue = '';
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
              if (_isRecording) {
                _stopRecording();
              } else {
                _startRecording();
              }
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
                onPressed: () async {
                  await analyzeVoice();
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
                  //get the solution from firebase based on the health issue
                  //example : health issue : bronchite
                  //collection("solutions").doc("bronchite")
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
                      //if the data is null show loading
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    } else {
                      Map<String, dynamic> solutions = snapshot.data!.data()!;
                      //get the solution list from firestore
                      List solutionsList = solutions["solution"];
                      //display the solutions list on listView
                      return ListView.builder(
                          itemCount: solutionsList.length,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(
                                  "Solution ${index + 1} for $_healthIssue"),
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
