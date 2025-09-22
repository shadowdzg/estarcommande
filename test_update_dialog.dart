import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/services/update_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Update Test', home: UpdateTestScreen());
  }
}

class UpdateTestScreen extends StatefulWidget {
  @override
  _UpdateTestScreenState createState() => _UpdateTestScreenState();
}

class _UpdateTestScreenState extends State<UpdateTestScreen> {
  String _status = 'Ready to test updates';

  @override
  void initState() {
    super.initState();
    _clearUpdateCache();
  }

  Future<void> _clearUpdateCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_update_check');
    setState(() {
      _status = 'Update cache cleared - ready to test';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Update Test'), backgroundColor: Colors.blue),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Update Test App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _testForceUpdate(),
              child: Text('Test Force Update Check'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _testManualUpdate(),
              child: Text('Test Manual Update Check'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _clearUpdateCache(),
              child: Text('Clear Update Cache'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testForceUpdate() async {
    setState(() {
      _status = 'Testing force update check...';
    });

    try {
      await UpdateService.checkForServerUpdate(context, forceCheck: true);
      setState(() {
        _status = 'Force update check completed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error during force update: $e';
      });
    }
  }

  Future<void> _testManualUpdate() async {
    setState(() {
      _status = 'Testing manual update check...';
    });

    try {
      await UpdateService.manualUpdateCheck(context);
      setState(() {
        _status = 'Manual update check completed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error during manual update: $e';
      });
    }
  }
}
