import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class AppConfig {
  // Web: 127.0.0.1
  // Android Emulator: 10.0.2.2
  // Real phone: http://YOUR_PC_IP:8000/api/
  static const String apiBase = "http://127.0.0.1:8000/api/";
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HCQ Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const DashboardScreen(),
    );
  }
}

// ==================== DASHBOARD (LIKE YOUR IMAGE) ====================
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Title + logout icon
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "HCQ MARKETING ATTENDANCE",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: "Logout",
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Logout"),
                          content: const Text("Guard logout (add login later)."),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("OK"),
                            )
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.logout, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(thickness: 1),
              const SizedBox(height: 30),

              // Tiles row (3)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  DashboardTile(
                    color: const Color(0xFF69C36B), // green
                    icon: Icons.qr_code_scanner,
                    label: "Scan Attendance",
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScanScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 28),
                  DashboardTile(
                    color: const Color(0xFF9B3B3B), // maroon
                    icon: Icons.groups,
                    label: "Employees",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EmployeesScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 28),
                  DashboardTile(
                    color: const Color(0xFFEF8B12), // orange
                    icon: Icons.calendar_month,
                    label: "Weekly Attendance",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WeeklyAttendanceScreen()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const DashboardTile({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            width: 140,
            height: 120,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 56),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ==================== SCANNER SCREEN ====================
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final String apiUrl = "${AppConfig.apiBase}scan/";

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
      final statusText = data["status_text"];

      final bool isLate = (data["is_late"] == true);
      final int lateMins = (data["late_minutes"] ?? 0) is int
          ? data["late_minutes"]
          : int.tryParse("${data["late_minutes"]}") ?? 0;

      final int otMins = (data["overtime_minutes"] ?? 0) is int
          ? data["overtime_minutes"]
          : int.tryParse("${data["overtime_minutes"]}") ?? 0;

      String extra = "";
      if (statusText == "CLOCKED IN" && isLate) extra = "LATE: $lateMins minute(s)";
      if (statusText == "CLOCKED OUT" && otMins > 0) extra = "OVERTIME: $otMins minute(s)";

      setState(() {
        bigStatus = statusText;
        subText = "$empName ($empCode)";
        extraText = extra;
      });
    } catch (e) {
      setState(() {
        bigStatus = "ERROR";
        subText = "Cannot connect to server";
        extraText = "Check API URL / server running";
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

// ==================== EMPLOYEES SCREEN (TAP TO VIEW DETAILS) ====================
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  bool loading = false;
  String error = "";
  List<dynamic> employees = [];
  final TextEditingController searchCtrl = TextEditingController();

  Future<void> fetchEmployees({String search = ""}) async {
    setState(() {
      loading = true;
      error = "";
    });

    try {
      final url = search.trim().isEmpty
          ? "${AppConfig.apiBase}employees/"
          : "${AppConfig.apiBase}employees/?search=${Uri.encodeComponent(search.trim())}";

      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);

      if (res.statusCode >= 400) {
        setState(() {
          error = (data is Map && data["detail"] != null)
              ? data["detail"].toString()
              : "Failed to load employees";
          employees = [];
        });
      } else {
        setState(() {
          employees = (data as List<dynamic>);
        });
      }
    } catch (e) {
      setState(() {
        error = "Cannot connect to server";
        employees = [];
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchEmployees();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Employees"),
        actions: [
          IconButton(
            onPressed: loading ? null : () => fetchEmployees(search: searchCtrl.text),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: "Search name or code",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchCtrl.clear();
                          fetchEmployees();
                          setState(() {});
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() {}), // updates clear button
              onSubmitted: (v) => fetchEmployees(search: v),
            ),
            const SizedBox(height: 12),

            if (error.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 10),
                      Expanded(child: Text(error)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 6),

            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : employees.isEmpty
                      ? const Center(child: Text("No employees found"))
                      : ListView.separated(
                          itemCount: employees.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = employees[i];
                            final name = e["full_name"]?.toString() ?? "";
                            final code = e["code"]?.toString() ?? "";

                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?"),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(code),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EmployeeDetailScreen(
                                      employeeId: e["id"],
                                      employeeName: name,
                                      employeeCode: code,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== WEEKLY ATTENDANCE PLACEHOLDER ====================
class WeeklyAttendanceScreen extends StatelessWidget {
  const WeeklyAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Weekly Attendance")),
      body: const Center(child: Text("Weekly attendance screen (we’ll connect to Django next).")),
    );
  }
}

// ==================== EMPLOYEE DETAIL SCREEN ====================
class EmployeeDetailScreen extends StatefulWidget {
  final dynamic employeeId;
  final String employeeName;
  final String employeeCode;

  const EmployeeDetailScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
  });

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  bool loading = false;
  String error = "";
  List<dynamic> records = [];

  Future<void> loadAttendance() async {
    setState(() {
      loading = true;
      error = "";
    });

    try {
      final url = "${AppConfig.apiBase}employees/${widget.employeeId}/attendance/";
      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);

      if (res.statusCode >= 400) {
        setState(() {
          error = (data is Map && data["detail"] != null)
              ? data["detail"].toString()
              : "Failed to load attendance";
          records = [];
        });
      } else {
        setState(() {
          records = (data["records"] as List<dynamic>);
        });
      }
    } catch (e) {
      setState(() {
        error = "Cannot connect to server";
        records = [];
      });
    } finally {
      setState(() => loading = false);
    }
  }

  String _fmt(dynamic iso) {
    if (iso == null) return "-";
    final s = iso.toString();
    final cleaned = s.replaceFirst("T", " ");
    if (cleaned.contains("+")) {
      final part = cleaned.split("+").first;
      return part.length >= 16 ? part.substring(0, 16) : part;
    }
    return cleaned.length >= 16 ? cleaned.substring(0, 16) : cleaned;
  }

  @override
  void initState() {
    super.initState();
    loadAttendance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeName),
        actions: [
          IconButton(
            onPressed: loading ? null : loadAttendance,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${widget.employeeName} (${widget.employeeCode})",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            if (error.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 10),
                      Expanded(child: Text(error)),
                    ],
                  ),
                ),
              ),

            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : records.isEmpty
                      ? const Center(child: Text("No attendance records"))
                      : ListView.separated(
                          itemCount: records.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final r = records[i];

                            final date = r["date"]?.toString() ?? "";
                            final timeIn = _fmt(r["time_in"]);
                            final timeOut = _fmt(r["time_out"]);

                            final bool absent = r["is_absent"] == true;
                            final bool late = r["is_late"] == true;

                            final int lateMins = (r["late_minutes"] ?? 0) is int
                                ? r["late_minutes"]
                                : int.tryParse("${r["late_minutes"]}") ?? 0;

                            final int otMins = (r["overtime_minutes"] ?? 0) is int
                                ? r["overtime_minutes"]
                                : int.tryParse("${r["overtime_minutes"]}") ?? 0;

                            String badge = "";
                            if (absent) {
                              badge = "ABSENT";
                            } else if (late) {
                              badge = "LATE ${lateMins}m";
                            }
                            if (!absent && otMins > 0) {
                              badge = badge.isEmpty ? "OT ${otMins}m" : "$badge • OT ${otMins}m";
                            }

                            return ListTile(
                              title: Text(date, style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Text("IN: $timeIn   OUT: $timeOut"),
                              trailing: badge.isEmpty
                                  ? null
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        color: Colors.black.withOpacity(0.06),
                                      ),
                                      child: Text(badge),
                                    ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
