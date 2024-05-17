import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
  AudioPlayer _audioPlayer = AudioPlayer();
  AudioRecorder record = AudioRecorder();

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

  void _startRecording() async {
    setState(() {
      _isRecording = true;
    });

    Directory tempDir = await getTemporaryDirectory();
    _filePath = '${tempDir.path}/recording.wav';
    setState(() {});

    await record.start(RecordConfig(), path: _filePath);
  }

  void _stopRecording() async {
    setState(() {
      _isRecording = false;
    });

    await record.stop();
  }

  void _playRecording() async {
    await _audioPlayer.play(DeviceFileSource(_filePath));
  }

  void _pauseRecording() async {
    await _audioPlayer.pause();
  }

  void _removeRecording() {
    setState(() {
      _filePath = '';
    });
  }

  Future<void> _analyzeVoice() async {
    setState(() {
      _healthIssue = 'Analyzing...';
    });

    var url = Uri.parse('http://your_flask_backend_url/analyze_voice');
    var request = http.MultipartRequest('POST', url)
      ..files.add(await http.MultipartFile.fromPath('voice', _filePath));

    var response = await request.send();

    if (response.statusCode == 200) {
      var responseBody = await response.stream.bytesToString();
      var data = jsonDecode(responseBody);
      setState(() {
        _healthIssue = data['health_issue'];
      });

      // Save the health issue to Firestore
      await FirebaseFirestore.instance.collection('issues').add({
        'issue_name': _healthIssue,
        'timestamp': DateTime.now(),
      });
    } else {
      setState(() {
        _healthIssue = 'Failed to analyze voice';
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
            onPanDown: (detail) {
              _startRecording();
            },
            onLongPressUp: () {
              _stopRecording();
            },
            onTap: () {
              if (_filePath.isNotEmpty) {
                _playRecording();
              }
            },
            child: _isRecording == true
                ? SizedBox(
                    height: 250,
                    width: 250,
                    child: RippleWave(
                      child: Icon(
                        Icons.mic_rounded,
                      ),
                    ),
                  )
                : CircleAvatar(
                    radius: 60,
                    child: Icon(
                      Icons.mic_rounded,
                      size: 30,
                    ),
                  ),
          ),
          SizedBox(height: 20),
          !_isRecording ? Text("Long press to start record ") : SizedBox(),
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
                    SizedBox(
                      width: 20,
                    ),
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
          Text(
            'Health Issue: $_healthIssue',
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}
