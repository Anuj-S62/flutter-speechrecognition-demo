import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_voiceassistant/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';
import '../utils/app_config.dart';

class Loading extends StatelessWidget {
  final AppConfig config;
  final String wakeWord;
  Loading({required this.config, required this.wakeWord});

  Future<void> initialize(BuildContext context) async {
    // Initialize the app
    final appState = context.read<AppState>();
    bool isWakeWordMode = false;
    String intentEngine = "snips";
    String streamId = "";
    bool isCommandProcessing = false;
    String commandProcessingText = "Processing...";
    String sttFramework = "vosk";
    bool onlineMode = false;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.reload();
    if(prefs.containsKey('isWakeWordMode')) {
      isWakeWordMode = await prefs.getBool('isWakeWordMode')!;
    }
    if(prefs.containsKey('intentEngine')) {
      intentEngine = await prefs.getString('intentEngine')!;
    }
    if(prefs.containsKey('streamId')) {
      streamId = await prefs.getString('streamId')!;
    }
    if(prefs.containsKey('isCommandProcessing')) {
      isCommandProcessing = await prefs.getBool('isCommandProcessing')!;
    }
    if(prefs.containsKey('commandProcessingText')) {
      commandProcessingText = await prefs.getString('commandProcessingText')!;
    }
    if(prefs.containsKey('sttFramework')) {
      sttFramework = await prefs.getString('sttFramework')!;
    }
    if(prefs.containsKey('onlineMode')) {
      onlineMode = await prefs.getBool('onlineMode')!;
    }

    appState.isWakeWordMode = isWakeWordMode;
    appState.intentEngine = intentEngine;
    appState.streamId = streamId;
    appState.isCommandProcessing = isCommandProcessing;
    appState.commandProcessingText = commandProcessingText;
    appState.sttFramework = sttFramework;
    appState.onlineMode = onlineMode;

    print('isWakeWordMode: $isWakeWordMode');
    print('intentEngine: $intentEngine');
    print('streamId: $streamId');
    print('isCommandProcessing: $isCommandProcessing');
    print('commandProcessingText: $commandProcessingText');
    print('sttFramework: $sttFramework');
    print('onlineMode: $onlineMode');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: initialize(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return HomePage(config: config, wakeWord: wakeWord);
        } else {
          return CupertinoActivityIndicator();
        }
      },
    );
  }
}
