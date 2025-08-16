import 'package:flutter/material.dart';
import 'emergency_sender.dart';

class EmergencyButton extends StatelessWidget {
  const EmergencyButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
          icon: const Icon(Icons.warning, color: Colors.white,),
          label: const Text("비상", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: () async {

            final result = await EmergencySender.sendEmergencyAlert(context);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result)),
            );
          },
        ),
      ),
    );
  }
}
