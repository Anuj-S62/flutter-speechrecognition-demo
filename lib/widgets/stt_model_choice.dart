import 'package:flutter/material.dart';

enum STTModel{
  vosk,
  whisper
}

class STTModelChoice extends StatefulWidget {
  final Function(STTModel) onModelChanged;
  final String theme;

  const STTModelChoice({
    Key? key,
    required this.onModelChanged,
    required this.theme
  }) : super(key: key);

  @override
  State<STTModelChoice> createState() => _STTModelChoiceState();
}

class _STTModelChoiceState extends State<STTModelChoice> {
  late STTModel _selectedModel;
  late String _theme;

  @override
  void initState() {
    super.initState();
    _selectedModel = STTModel.vosk;
    _theme = widget.theme;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        InkWell(
          onTap: () => _onModelChanged(STTModel.vosk),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.0),
            bottomLeft: Radius.circular(20.0),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 17.5, vertical: 5.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.0),
                bottomLeft: Radius.circular(20.0),
              ),
              color: _selectedModel == STTModel.vosk
                  ? Colors.green
                  : _theme == "dark" || _theme == "textured-dark"
                  ? Colors.black
                  : Colors.white,
              border: Border.all(
                color: Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedModel == STTModel.vosk
                      ? Icons.check
                      : Icons.transcribe_sharp,
                  color: _selectedModel == STTModel.vosk
                      ? Colors.white
                      : Colors.green,
                ),
                SizedBox(width: 8),
                Text(
                  'Vosk',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: _selectedModel == STTModel.vosk
                        ? Colors.white
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () => _onModelChanged(STTModel.whisper),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(20.0),
            bottomRight: Radius.circular(20.0),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 17.5, vertical: 5.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(20.0),
                bottomRight: Radius.circular(20.0),
              ),
              color: _selectedModel == STTModel.whisper
                  ? Colors.green
                  : _theme == "dark" || _theme == "textured-dark"
                  ? Colors.black
                  : Colors.white,
              border: Border.all(
                color: Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedModel == STTModel.whisper
                      ? Icons.check
                      : Icons.transcribe_sharp,
                  color: _selectedModel == STTModel.whisper
                      ? Colors.white
                      : Colors.green,
                ),
                SizedBox(width: 8),
                Text(
                  'Whisper',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: _selectedModel == STTModel.whisper
                        ? Colors.white
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _onModelChanged(STTModel newModel) {
    setState(() {
      _selectedModel = newModel;
    });

    // Call the callback function to notify the engine change
    widget.onModelChanged(newModel);
  }
}