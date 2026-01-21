import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guard Attendance Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const ScanScreen(),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // CHANGE THIS DEPENDING ON DEVICE:
  // Android Emulator -> http://10.0.2.2:8000/api/scan/
  // Real phone -> http://YOUR_PC_IP:8000/api/scan/  (e.g. http://192.168.1.10:8000/api/scan/)
 // final String apiUrl = "http://10.0.2.2:8000/api/scan/";
 final String apiUrl = "http://127.0.0.1:8000/api/scan/";

  bool busy = false;
  String bigStatus = "READY TO SCAN";
  String subText = "Scan employee ID";
  String extraText = "";

  DateTime _lastScanTime = DateTime.fromMillisecondsSinceEpoch(0);

  bool _antiSpamScan() {
    final now = DateTime.now();
    if (now.difference(_lastScanTime).inMilliseconds < 1200) return false;
    _lastScanTime = now;
    return true;
  }

  Future<void> submitCode(String code) async {
    if (busy) return;

    setState(() {
      busy = true;
      bigStatus = "PROCESSING...";
      subText = "Please wait";
      extraText = "";
    });

    try {
      final res = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"code": code}),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode >= 400) {
        setState(() {
          bigStatus = "ERROR";
          subText = data["detail"]?.toString() ?? "Something went wrong";
          extraText = "";
        });
        return;
      }

      final empName = data["employee"]["full_name"];
      final empCode = data["employee"]["code"];
      final statusText = data["status_text"]; // CLOCKED IN / CLOCKED OUT

      final bool isLate = (data["is_late"] == true);
      final int lateMins = (data["late_minutes"] ?? 0) is int
          ? data["late_minutes"]
          : int.tryParse("${data["late_minutes"]}") ?? 0;

      final int otMins = (data["overtime_minutes"] ?? 0) is int
          ? data["overtime_minutes"]
          : int.tryParse("${data["overtime_minutes"]}") ?? 0;

      String extra = "";
      if (statusText == "CLOCKED IN" && isLate) {
        extra = "LATE: $lateMins minute(s)";
      }
      if (statusText == "CLOCKED OUT" && otMins > 0) {
        extra = "OVERTIME: $otMins minute(s)";
      }

      setState(() {
        bigStatus = statusText;
        subText = "$empName ($empCode)";
        extraText = extra;
      });
    } catch (e) {
      setState(() {
        bigStatus = "ERROR";
        subText = "Cannot connect to server";
        extraText = "Check API URL / Wi-Fi / server running";
      });
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance Scanner")),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: MobileScanner(
              onDetect: (capture) {
                if (!_antiSpamScan()) return;
                final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
                final raw = barcode?.rawValue?.trim();
                if (raw == null || raw.isEmpty) return;
                submitCode(raw);
              },
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bigStatus,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(subText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                  if (extraText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(extraText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () {
                            setState(() {
                              bigStatus = "READY TO SCAN";
                              subText = "Scan employee ID";
                              extraText = "";
                            });
                          },
                    child: const Text("Reset"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
