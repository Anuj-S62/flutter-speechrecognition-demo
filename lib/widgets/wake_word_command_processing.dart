import 'package:flutter/material.dart';

class ProcessingCommandSection extends StatefulWidget {
  @override
  ProcessingCommandSectionState createState() => ProcessingCommandSectionState();
}

class ProcessingCommandSectionState extends State<ProcessingCommandSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    // Create an animation controller
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2), // Adjust the duration as needed
    );

    // Start the animation
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose of the animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _controller.value * 2.0 * 3.1415927, // 2 * pi
              child: Icon(
                Icons.autorenew, // Replace with your processing icon
                size: 60,
                color: Colors.blueAccent,
              ),
            );
          },
        ),
        SizedBox(height: 8),
        Text(
          'Processing...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
