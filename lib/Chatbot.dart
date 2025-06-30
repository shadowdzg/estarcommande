import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'app_drawer.dart';

class ChatBotPage extends StatefulWidget {
  const ChatBotPage({Key? key}) : super(key: key);

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();

  // Simulated user role - replace with real auth
  final String currentUserRole = 'admin';

  // Store fetched data
  Map<String, dynamic>? salesStats;
  List<dynamic>? inactiveClients;

  Future<void> _fetchSalesStats() async {
    try {
      final response = await http.get(Uri.parse('http://92.222.248.113:3000/api/v1/sales/stats'));
      if (response.statusCode == 200) {
        setState(() {
          salesStats = json.decode(response.body);
        });
      } else {
        _addMessage("🤖", "Failed to fetch sales stats.");
      }
    } catch (e) {
      _addMessage("🤖", "Error fetching sales stats: $e");
    }
  }

  Future<void> _fetchInactiveClients(int days) async {
    try {
      final url = Uri.parse('http://92.222.248.113:3000/api/v1/clients/inactive?days=$days');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          inactiveClients = json.decode(response.body);
        });
      } else {
        _addMessage("🤖", "Failed to fetch inactive clients.");
      }
    } catch (e) {
      _addMessage("🤖", "Error fetching inactive clients: $e");
    }
  }

  void _addMessage(String sender, String message) {
    setState(() {
      _messages.add({'sender': sender, 'message': message});
    });
  }

  void _handleSubmitted(String text) {
    if (text.isEmpty) return;

    _addMessage("You", text);
    _controller.clear();

    // Detect query type
    if (text.contains('sales') && (text.contains('stats') || text.contains('summary'))) {
      _addMessage("🤖", "Fetching latest sales stats...");
      _fetchSalesStats().then((_) {
        if (salesStats != null) {
          _addMessage("🤖", "📊 Here are your sales stats:\n\n" +
              salesStats!.entries.map((e) => "${e.key}: ${e.value}").join("\n"));
        }
      });

    } else if ((text.contains('inactive') || text.contains('not purchased')) &&
        (text.contains('client') || text.contains('clients'))) {

      int days = 30; // Default
      final RegExp exp = RegExp(r'\d+');
      final match = exp.firstMatch(text);
      if (match != null) {
        days = int.tryParse(match.group(0)!) ?? days;
      }

      _addMessage("🤖", "🔍 Finding clients with no purchases in last $days days...");
      _fetchInactiveClients(days).then((_) {
        if (inactiveClients != null && inactiveClients!.isNotEmpty) {
          _addMessage("🤖", "Here are clients with no recent orders:\n" +
              inactiveClients!
                  .map((c) => "- ${c['clientName']} (${c['wilaya']})")
                  .join('\n'));
        } else {
          _addMessage("🤖", "No inactive clients found.");
        }
      });

    } else {
      _addMessage("🤖", "I'm here to help with:\n- Sales stats\n- Inactive clients");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Assistant'),
      ),
      drawer: const AppDrawer(), // <-- Add this line
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return ListTile(
                  title: Text(msg['sender']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(msg['message']!),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _handleSubmitted,
                    decoration: const InputDecoration(hintText: "Ask something..."),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _handleSubmitted(_controller.text),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}