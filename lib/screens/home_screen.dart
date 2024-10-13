import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_voiceassistant/widgets/online_mode_choice.dart';
import 'package:flutter_voiceassistant/widgets/try_commands.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/app_state.dart';
import '../widgets/nlu_engine_choice.dart';
import '../widgets/assistant_mode_choice.dart';
import '../widgets/record_command_button.dart';
import '../widgets/listen_wake_word_section.dart';
import '../widgets/chat_section.dart';
// import '../grpc/generated/voice_agent.pbgrpc.dart';
import '../grpc/voice_agent_client.dart';
import '../utils/app_config.dart';
import '../widgets/stt_model_choice.dart';
import '../widgets/wake_word_command_processing.dart';
import '../widgets/wake_word_recording.dart';
import 'package:protos/val_api.dart';

class HomePage extends StatefulWidget {
  final AppConfig config;
  final String wakeWord;

  HomePage({Key? key, required this.config, required this.wakeWord});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late AppConfig _config; // Store the config as an instance variable
  late String _wakeWord; // Store the wake word as an instance variable
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> chatMessages = [];
  StreamSubscription<WakeWordStatus>? _wakeWordStatusSubscription;
  late VoiceAgentClient voiceAgentClient;

  @override
  void initState() {
    super.initState();
    _config = widget.config; // Initialize _config in the initState
    _wakeWord = widget.wakeWord; // Initialize _wakeWord in the initState
    final appState = context.read<AppState>();
    if(appState.isWakeWordMode){
      addChatMessage(
          'Switched to Wake Word mode. I\'ll listen for the wake word "$_wakeWord" before responding.');
      _startWakeWordDetection(context);
    }
    else{
      addChatMessage(
          "Assistant in Manual mode. You can send commands directly by pressing the record button.");
    }

  }

  Future<void> changeAssistantMode(BuildContext context, AssistantMode newMode) async {
    final appState = context.read<AppState>();
    clearChatMessages();
    appState.streamId = "";
    appState.isWakeWordDetected = false;
    appState.isCommandProcessing = false;

    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (newMode == AssistantMode.wakeWord) {
      await prefs.setBool('isWakeWordMode', true);
      addChatMessage(
          'Switched to Wake Word mode. I\'ll listen for the wake word "$_wakeWord" before responding.');

      // Close old ongoing wake word detection loop if any
      if (appState.isWakeWordMode) {
        appState.isWakeWordMode = false;
        toggleWakeWordDetection(context, false);
      }
      // Start a new wake word detection loop
      if (!appState.isWakeWordMode) {
        appState.isWakeWordMode = true;
        toggleWakeWordDetection(context, true);
      }
    } else if (newMode == AssistantMode.manual) {
      prefs.setBool('isWakeWordMode', false);
      addChatMessage(
          'Switched to Manual mode. You can send commands directly by pressing record button.');

      // Close old ongoing wake word detection loop if any
      if (appState.isWakeWordMode) {
        appState.isWakeWordMode = false;
        toggleWakeWordDetection(context, false);
      }
    }
    setState(() {}); // Trigger a rebuild
  }

  Future<void> changeIntentEngine(BuildContext context, NLUEngine newEngine) async {
    final appState = context.read<AppState>();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (newEngine == NLUEngine.snips) {
      appState.intentEngine = "snips";
      await prefs.setString("intentEngine","snips");
      addChatMessage(
          'Switched to 🚀 Snips engine. Lets be precise and accurate.');
    } else if (newEngine == NLUEngine.rasa) {
      appState.intentEngine = "rasa";
      await prefs.setString("intentEngine","rasa");
      addChatMessage(
          'Switched to 🤖 RASA engine. Conversations just got smarter!');
    }
    print(appState.intentEngine);
    setState(() {}); // Trigger a rebuild
  }

  Future<void> changeSTTFramework(BuildContext context, STTModel newModel) async {
    final appState = context.read<AppState>();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (newModel == STTModel.vosk) {
      appState.sttFramework = "vosk";
      await prefs.setString("sttFramework", "vosk");
      // vosk is fast and efficient
      addChatMessage(
          'Switched to 🚀 Vosk framework. Lets be quick and efficient.');
    } else if (newModel == STTModel.whisper) {
      appState.sttFramework = "whisper";
      await prefs.setString("sttFramework", "whisper");
      addChatMessage(
          'Switched to 🤖 Whisper framework. Conversations just got smarter!');
    }
    print(appState.sttFramework);
    setState(() {}); // Trigger a rebuild
  }

  Future<void> toggleOnlineMode(BuildContext context, OnlineModeEnum mode) async {
    final appState = context.read<AppState>();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mode == OnlineModeEnum.enabled) {
      appState.onlineMode = true;
      await prefs.setBool('onlineMode', true);
      addChatMessage(
          'Switched to Online mode. I\'ll be connected to the internet for better results.');
    } else {
      appState.onlineMode = false;
      await prefs.setBool('onlineMode', false);
      addChatMessage(
          'Switched to Offline mode. I\'ll be disconnected from the internet.');
    }
    setState(() {}); // Trigger a rebuild
  }

  void addChatMessage(String text, {bool isUserMessage = false}) {
    final newMessage = ChatMessage(text: text, isUserMessage: isUserMessage);
    setState(() {
      chatMessages.add(newMessage);
    });
    // Use a post-frame callback to scroll after the frame has been rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  // Function to clear all chat messages
  void clearChatMessages() {
    setState(() {
      chatMessages.clear();
    });
  }

  void changeCommandRecordingState(
      BuildContext context, bool isRecording) async {
    final appState = context.read<AppState>();
    if (isRecording) {
      appState.streamId = await startRecording();
    } else {
      appState.commandProcessingText = "Converting speech to text...";
      appState.isCommandProcessing = true;
      setState(
          () {}); // Trigger a rebuild to ensure the loading indicator is shown, tis a bad practice though but deosn't heavily affect the performance
      final response =
          await stopRecording(appState.streamId, appState.intentEngine,appState.sttFramework,appState.onlineMode);
      // Process and store the result
      if (response.status == RecognizeStatusType.REC_SUCCESS) {
        appState.commandProcessingText = "Executing command...";
        await executeCommand(
            response); // Call executeVoiceCommand with the response
      }
      appState.isCommandProcessing = false;
    }
  }

  // gRPC related methods are as follows
  // Function to start and stop the wake word detection loop
  void toggleWakeWordDetection(BuildContext context, bool startDetection) {
    final appState = context.read<AppState>();
    if (startDetection) {
      appState.isWakeWordDetected = false;
      _startWakeWordDetection(context);
    } else {
      _stopWakeWordDetection();
    }
  }

  // Function to start listening for wake word status responses
  void _startWakeWordDetection(BuildContext context) {
    final appState = context.read<AppState>();
    // Base condition
    if(appState.isWakeWordMode==false){
      return;
    }
    setState(() {});
    voiceAgentClient = VoiceAgentClient(_config.grpcHost, _config.grpcPort);
    appState.isWakeWordDetected = false;
    appState.isCommandProcessing = false;
    _wakeWordStatusSubscription = voiceAgentClient.detectWakeWord().listen(
          (response) async {
        if (response.status) {
          // Wake word detected, handle this case here
          _stopWakeWordDetection();
          appState.isWakeWordDetected = true;
          addChatMessage('Wake word detected! Starting recording...');

          // Start recording
          appState.isCommandProcessing = false;
          String streamId = await startRecording();
          if (streamId.isNotEmpty) {
            addChatMessage('Recording started. Please speak your command.');

            // Wait for 4-5 seconds
            await Future.delayed(Duration(seconds: appState.recordingTime));

            // Stop recording and get the response
            appState.isCommandProcessing = true;
            RecognizeResult recognizeResult = await stopRecording(streamId, appState.intentEngine,appState.sttFramework,appState.onlineMode);
            // Execute the command
            await executeCommand(recognizeResult);

            // Wait for 1-2 seconds before resuming wake word detection
            await Future.delayed(Duration(seconds: 1));

            // Resume wake word detection
            _startWakeWordDetection(context);
          } else {
            addChatMessage('Failed to start recording. Please try again.');
            // Resume wake word detection

            _startWakeWordDetection(context);
          }
        }
      },
      onError: (error) {
        print('Error during wake word detection: $error');
        // Set _isDetectingWakeWord to false to stop the loop
        _stopWakeWordDetection();
        // Resume wake word detection
        _startWakeWordDetection(context);
      },
      cancelOnError: true,
    );
  }

  // Function to stop listening for wake word status responses
  void _stopWakeWordDetection() {
    _wakeWordStatusSubscription?.cancel();
    voiceAgentClient.shutdown();
  }

  Future<String> startRecording() async {
    String streamId = "";
    voiceAgentClient = VoiceAgentClient(_config.grpcHost, _config.grpcPort);
    try {
      // Create a RecognizeControl message to start recording
      final controlMessage = RecognizeVoiceControl()
        ..action = RecordAction.START
        ..recordMode = RecordMode
            .MANUAL; // You can change this to your desired record mode

      // Create a Stream with the control message
      final controlStream = Stream.fromIterable([controlMessage]);

      // Call the gRPC method to start recording
      final response =
          await voiceAgentClient.recognizeVoiceCommand(controlStream);

      streamId = response.streamId;
    } catch (e) {
      print('Error starting recording: $e');
      addChatMessage('Recording failed. Please try again.');
    }
    return streamId;
  }

  Future<RecognizeResult> stopRecording(
      String streamId, String nluModel, String stt,bool isOnlineMode) async {

    try {
      NLUModel model = NLUModel.RASA;
      if (nluModel == "snips") {
        model = NLUModel.SNIPS;
      }
      STTFramework sttFramework = STTFramework.VOSK;
      if (stt == "whisper") {
        sttFramework = STTFramework.WHISPER;
      }
      OnlineMode onlineMode = OnlineMode.OFFLINE;
      if (isOnlineMode) {
        onlineMode = OnlineMode.ONLINE;
      }
      // Create a RecognizeControl message to stop recording
      final controlMessage = RecognizeVoiceControl()
        ..action = RecordAction.STOP
        ..nluModel = model
        ..streamId =
            streamId // Use the same stream ID as when starting recording
        ..recordMode = RecordMode.MANUAL
        ..sttFramework = sttFramework
        ..onlineMode = onlineMode;


      // Create a Stream with the control message
      final controlStream = Stream.fromIterable([controlMessage]);

      // Call the gRPC method to stop recording
      final response =
          await voiceAgentClient.recognizeVoiceCommand(controlStream);

      // Process and store the result
      if (response.status == RecognizeStatusType.REC_SUCCESS) {
        final command = response.command;
        // final intent = response.intent;
        // final intentSlots = response.intentSlots;
        addChatMessage(command, isUserMessage: true);
      } else if (response.status == RecognizeStatusType.INTENT_NOT_RECOGNIZED) {
        final command = response.command;
        addChatMessage(command, isUserMessage: true);
        addChatMessage(
            "Unable to undertsand the intent behind your request. Please try again.");
      } else {
        addChatMessage(
            'Failed to process your voice command. Please try again.');
      }
      await voiceAgentClient.shutdown();
      return response;
    } catch (e) {
      print('Error stopping recording: $e');
      addChatMessage('Failed to process your voice command. Please try again.');
      await voiceAgentClient.shutdown();
      return RecognizeResult()..status = RecognizeStatusType.REC_ERROR;
    }
    // await voiceAgentClient.shutdown();
  }

  Future<RecognizeResult> recognizeTextCommand(
      String command, String nluModel) async {
    voiceAgentClient = VoiceAgentClient(_config.grpcHost, _config.grpcPort);
    try {
      NLUModel model = NLUModel.RASA;
      if (nluModel == "snips") {
        model = NLUModel.SNIPS;
      }
      // Create a RecognizeControl message to stop recording
      final controlMessage = RecognizeTextControl()
        ..textCommand = command
        ..nluModel = model;

      // Call the gRPC method to stop recording
      final response =
          await voiceAgentClient.recognizeTextCommand(controlMessage);

      // Process and store the result
      if (response.status == RecognizeStatusType.REC_SUCCESS) {
        // Do nothing
      } else if (response.status == RecognizeStatusType.INTENT_NOT_RECOGNIZED) {
        final command = response.command;
        addChatMessage(command, isUserMessage: true);
        addChatMessage(
            "Unable to undertsand the intent behind your request. Please try again.");
      } else {
        addChatMessage(
            'Failed to process your text command. Please try again.');
      }
      await voiceAgentClient.shutdown();
      return response;
    } catch (e) {
      print('Error encountered during text command recognition: $e');
      addChatMessage('Failed to process your text command. Please try again.');
      await voiceAgentClient.shutdown();
      return RecognizeResult()..status = RecognizeStatusType.REC_ERROR;
    }
  }

  Future<void> executeCommand(RecognizeResult response) async {
    voiceAgentClient = VoiceAgentClient(_config.grpcHost, _config.grpcPort);
    try {
      // Create an ExecuteInput message using the response from stopRecording
      final executeInput = ExecuteInput()
        ..intent = response.intent
        ..intentSlots.addAll(response.intentSlots);

      // Call the gRPC method to execute the voice command
      final execResponse = await voiceAgentClient.executeCommand(executeInput);

      // Handle the response as needed
      if (execResponse.status == ExecuteStatusType.EXEC_SUCCESS) {
        final commandResponse = execResponse.response;
        addChatMessage(commandResponse);
      } else if (execResponse.status == ExecuteStatusType.KUKSA_CONN_ERROR) {
        final commandResponse = execResponse.response;
        addChatMessage(commandResponse);
      } else {
        // Handle the case when execution fails
        addChatMessage(
            'Failed to execute your voice command. Please try again.');
      }
    } catch (e) {
      print('Error executing voice command: $e');
      // Handle any errors that occur during the gRPC call
      addChatMessage('Failed to execute your voice command. Please try again.');
    }
    await voiceAgentClient.shutdown();
  }

  Future<void> handleCommandTap(String command) async {
    final appState = context.read<AppState>();
    addChatMessage(command, isUserMessage: true);
    appState.isCommandProcessing = true;
    appState.commandProcessingText = "Recognizing intent...";

    setState(
        () {}); // Trigger a rebuild to ensure the loading indicator is shown, tis a bad practice though but deosn't heavily affect the performance

    final response = await recognizeTextCommand(command, appState.intentEngine);
    // Process and store the result
    if (response.status == RecognizeStatusType.REC_SUCCESS) {
      appState.commandProcessingText = "Executing command...";
      setState(
          () {}); // Trigger a rebuild to ensure the loading indicator is shown, tis a bad practice though but deosn't heavily affect the performance
      await executeCommand(
          response); // Call executeVoiceCommand with the response
    }

    appState.isCommandProcessing = false;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width:
                MediaQuery.of(context).size.width * 0.85, // 85% of screen width
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(
                      top: 25,
                      bottom: 25), // Adjust the top and bottom margin as needed
                  child: Image.asset(
                    _config.theme == "dark" || _config.theme == "textured-dark"
                        ? 'assets/agl_logo_darkmode.png'
                        : 'assets/agl_logo_lightmode.png',
                    width: 300,
                    fit: BoxFit
                        .contain, // Ensure the image fits within the specified dimensions
                  ),
                ),
                Text(
                  "Voice Assistant",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 15),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          flex: 1,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                              child: Card(
                                color: _config.theme == "textured-dark" ||
                                        _config.theme == "textured-light"
                                    ? Colors.transparent
                                    : null,
                                elevation: 4, // Add elevation for shadow
                                shadowColor: _config.theme == "textured-dark" ||
                                        _config.theme == "textured-light"
                                    ? Colors.transparent
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Assistant Mode',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 16), // Add spacing if needed
                                      Center(
                                        child: Consumer<AppState>(
                                          builder: (context, appState, _) {
                                            return AssistantModeChoice(
                                              onModeChanged: (newMode) {
                                                changeAssistantMode(
                                                    context, newMode);
                                                print(newMode);
                                              },
                                              theme: _config.theme,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 20), // Add spacing between buttons

                        Flexible(
                          flex: 1,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                              child: Card(
                                color: _config.theme == "textured-dark" ||
                                        _config.theme == "textured-light"
                                    ? Colors.transparent
                                    : null,
                                elevation: 4, // Add elevation for shadow
                                shadowColor: _config.theme == "textured-dark" ||
                                        _config.theme == "textured-light"
                                    ? Colors.transparent
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Intent Engine',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 16), // Add spacing if needed
                                      Center(
                                        child: Consumer<AppState>(
                                          builder: (context, appState, _) {
                                            return NLUEngineChoice(
                                              onEngineChanged: (newEngine) {
                                                changeIntentEngine(
                                                    context, newEngine);
                                                print(newEngine);
                                              },
                                              theme: _config.theme,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          flex: 1,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                              child: Card(
                                color: _config.theme == "textured-dark" ||
                                    _config.theme == "textured-light"
                                    ? Colors.transparent
                                    : null,
                                elevation: 4, // Add elevation for shadow
                                shadowColor: _config.theme == "textured-dark" ||
                                    _config.theme == "textured-light"
                                    ? Colors.transparent
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Speech-to-Text Model',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 16), // Add spacing if needed
                                      Center(
                                        child: Consumer<AppState>(
                                          builder: (context, appState, _) {
                                            return STTModelChoice(
                                              onModelChanged: (newModel) {
                                                changeSTTFramework(
                                                    context, newModel);
                                                print(newModel);
                                              },
                                              theme: _config.theme,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 20), // Add spacing between buttons

                        Flexible(
                          flex: 1,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                              child: Card(
                                color: _config.theme == "textured-dark" ||
                                    _config.theme == "textured-light"
                                    ? Colors.transparent
                                    : null,
                                elevation: 4, // Add elevation for shadow
                                shadowColor: _config.theme == "textured-dark" ||
                                    _config.theme == "textured-light"
                                    ? Colors.transparent
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Online Mode',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 16), // Add spacing if needed
                                      Center(
                                        child: Consumer<AppState>(
                                          builder: (context, appState, _) {
                                            return OnlineModeChoice(
                                              onModeChanged: (mode) {
                                                toggleOnlineMode(context, mode);
                                                print(mode);
                                              },
                                              theme: _config.theme,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),


                  ],
                ),
                SizedBox(height: 15),
                ChatSection(
                  scrollController: _scrollController,
                  chatMessages: chatMessages,
                  addChatMessage: addChatMessage,
                  theme: _config.theme,
                ),
                SizedBox(height: 10),
                if (!appState.isWakeWordMode)
                  TryCommandsSection(
                      onCommandTap: handleCommandTap, theme: _config.theme),
                SizedBox(height: 30),
                if (!appState.isWakeWordMode)
                  if (!appState.isCommandProcessing)
                    Center(
                      child:
                          Consumer<AppState>(builder: (context, appState, _) {
                        return RecordCommandButton(
                          onRecordingStateChanged: (isRecording) {
                            changeCommandRecordingState(context, isRecording);
                          },
                        );
                      }),
                    )
                  else
                    Column(children: [
                      Center(
                        child: CircularProgressIndicator(),
                      ),
                      SizedBox(height: 12),
                      Center(
                        child: Text(
                          appState.commandProcessingText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ])
                else
                  if(!appState.isWakeWordDetected)
                    Center(
                      child: Consumer<AppState>(
                      builder: (context, appState, _) {
                          return ListeningForWakeWordSection();
                        },
                      ),
                    )
                else
                if (!appState.isCommandProcessing && appState.isWakeWordDetected)
                  Center(
                    child:
                    Consumer<AppState>(builder: (context, appState, _) {
                      return WakeWordRecording();
                    }),
                  )
                else
                    Center(
                      child: ProcessingCommandSection(),
                    ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
