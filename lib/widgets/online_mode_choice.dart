import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';

enum OnlineModeEnum{
  enabled,
  disabled
}

class OnlineModeChoice extends StatefulWidget {
  final Function(OnlineModeEnum) onModeChanged;
  final String theme;

  const OnlineModeChoice({
    Key? key,
    required this.onModeChanged,
    required this.theme
  }) : super(key: key);

  @override
  State<OnlineModeChoice> createState() => _OnlineModeChoiceState();
}

class _OnlineModeChoiceState extends State<OnlineModeChoice> {
  late OnlineModeEnum _selectedMode;
  late String _theme;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _selectedMode = appState.onlineMode ? OnlineModeEnum.enabled : OnlineModeEnum.disabled;
    _theme = widget.theme;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        InkWell(
          onTap: () => _onModelChanged(OnlineModeEnum.disabled),
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
              color: _selectedMode == OnlineModeEnum.disabled
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
                  _selectedMode == OnlineModeEnum.disabled
                      ? Icons.check
                      : Icons.cloud_off_outlined,
                  color: _selectedMode == OnlineModeEnum.disabled
                      ? Colors.white
                      : Colors.green,
                ),
                SizedBox(width: 8),
                Text(
                  'Disabled',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: _selectedMode == OnlineModeEnum.disabled
                        ? Colors.white
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () => _onModelChanged(OnlineModeEnum.enabled),
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
              color: _selectedMode == OnlineModeEnum.enabled
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
                  _selectedMode == OnlineModeEnum.enabled
                      ? Icons.check
                      : Icons.cloud_done_outlined,
                  color: _selectedMode == OnlineModeEnum.enabled
                      ? Colors.white
                      : Colors.green,
                ),
                SizedBox(width: 8),
                Text(
                  'Enabled',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: _selectedMode == OnlineModeEnum.enabled
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

  void _onModelChanged(OnlineModeEnum newMode) {
    setState(() {
      _selectedMode = newMode;
    });

    // Call the callback function to notify the engine change
    widget.onModeChanged(newMode);
  }
}