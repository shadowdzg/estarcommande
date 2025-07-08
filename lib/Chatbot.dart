import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatBotPage extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  const ChatBotPage({Key? key, required this.orders}) : super(key: key);

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  List<Map<String, dynamic>> allOrders = [];

  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // Preset queries for sales analysis
  final List<Map<String, String>> _presetQueries = [
    {
      'title': 'أفضل 10 عملاء',
      'query': 'من هم أفضل 10 عملاء من حيث إجمالي الطلبات والإيرادات؟',
      'icon': '👑',
    },
    {
      'title': 'إحصائيات المبيعات',
      'query':
          'أعطني ملخص شامل لإحصائيات المبيعات: إجمالي المبيعات، عدد الطلبات، متوسط قيمة الطلب',
      'icon': '📊',
    },
    {
      'title': 'المنتجات الأكثر مبيعاً',
      'query': 'ما هي المنتجات الأكثر مبيعاً وكم عدد الطلبات لكل منتج؟',
      'icon': '🏆',
    },
    {
      'title': 'حالة الطلبات',
      'query': 'ما هو توزيع حالات الطلبات (معلقة، مكتملة، ملغية)؟',
      'icon': '📋',
    },
    {
      'title': 'العملاء غير النشطين',
      'query':
          'من هم العملاء الذين لم يقوموا بطلبات مؤخراً أو لديهم نشاط منخفض؟',
      'icon': '😴',
    },
    {
      'title': 'اتجاهات المبيعات',
      'query':
          'ما هي اتجاهات المبيعات الشهرية والأسبوعية؟ هل هناك نمو أم انخفاض؟',
      'icon': '📈',
    },
  ];

  @override
  void initState() {
    super.initState();
    allOrders = widget.orders;

    // Add welcome message
    _addMessage(
      "🤖",
      "مرحباً! أنا مساعدك الذكي لتحليل المبيعات. سأقوم بتحميل بيانات الطلبات أولاً...",
    );

    _fetchAllOrdersForAnalysis(); // Fetch all orders when initializing
  }

  // Function to fetch ALL orders for AI analysis (not paginated)
  Future<void> _fetchAllOrdersForAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    if (token.isEmpty) {
      _addMessage(
        "🤖",
        "لم يتم العثور على رمز المصادقة. يرجى تسجيل الدخول مرة أخرى.",
      );
      return;
    }

    // Fetch a limited number of recent orders for analysis
    final Map<String, String> queryParams = {
      'skip': '0',
      'take': '1000', // Get only the last 1000 orders for analysis
    };

    final uri = Uri.parse(
      'http://92.222.248.113:3000/api/v1/commands',
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (!mounted) return;

        setState(() {
          final ordersList = (data['data'] ?? []) as List<dynamic>;
          allOrders = ordersList.map<Map<String, dynamic>>((item) {
            return {
              'id': item['id'],
              'client': item['client']?['clientName'] ?? 'Unknown',
              'product': item['operator'] ?? 'Unknown',
              'quantity': item['amount'] ?? 0,
              'prix': double.tryParse(item['prix']?.toString() ?? '0') ?? 0.0,
              'prixPercent':
                  double.tryParse(
                    (item['pourcentage'] ?? '0').toString().replaceAll('%', ''),
                  ) ??
                  0,
              'state': item['isValidated'] ?? 'En Attente',
              'name': item['user']?['username'] ?? 'Unknown',
              'number': item['number'] ?? 'Unknown',
              'accepted': item['accepted'] ?? 'Unknown',
              'acceptedBy': item['acceptedBy'] ?? ' ',
              'date': item['createdAt'] ?? '',
            };
          }).toList();
        });

        // Show success message
        if (allOrders.isNotEmpty) {
          _addMessage(
            "🤖",
            "تم تحميل ${allOrders.length} طلب بنجاح! يمكنك الآن طرح أسئلتك حول تحليل المبيعات أو استخدام الأزرار السريعة أدناه.",
          );
        } else {
          _addMessage(
            "🤖",
            "لم يتم العثور على أي طلبات في النظام. يرجى التأكد من وجود بيانات في قاعدة البيانات.",
          );
        }
      } else {
        if (!mounted) return;
        _addMessage(
          "🤖",
          "فشل في تحميل الطلبات من الخادم. رمز الخطأ: ${response.statusCode}. يرجى المحاولة مرة أخرى.",
        );
      }
    } catch (e) {
      if (!mounted) return;
      _addMessage(
        "🤖",
        "حدث خطأ في الاتصال بالخادم: $e. يرجى التحقق من الاتصال بالإنترنت والمحاولة مرة أخرى.",
      );
    }
  }

  void _addMessage(String sender, String message) {
    setState(() {
      _messages.add({'sender': sender, 'message': message});
    });
  }

  void _handleSubmitted(String text) {
    if (text.isEmpty) return;

    // Check if we have orders to analyze
    if (allOrders.isEmpty) {
      _addMessage("أنت", text);
      _addMessage(
        "🤖",
        "عذراً، لا توجد بيانات طلبات متاحة للتحليل. يرجى الضغط على زر التحديث أولاً لتحميل الطلبات.",
      );
      return;
    }

    _handleLLMQuery(text);
    _controller.clear();
  }

  Future<String> askLLM(String prompt) async {
    final apiKey =
        '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'; // Get from openrouter.ai
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer':
          'https://github.com/shadowdzg/estarcommande', // required by OpenRouter
    };
    final body = jsonEncode({
      "model": "openai/gpt-4o-mini", // <-- updated model name
      "messages": [
        {
          "role": "system",
          "content":
              "أنت مساعد ذكي متخصص في إحصائيات المبيعات ونشاط العملاء. يجب أن تجيب دائماً باللغة العربية. قم بتحليل البيانات المقدمة وقدم إجابات مفصلة ومفيدة بالعربية.",
        },
        {"role": "user", "content": prompt},
      ],
      "max_tokens": 2048, // Increased from 512 to allow for longer responses
      "temperature": 0.7, // Added for more natural responses
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      return "عذراً، لم أتمكن من الحصول على رد من الذكاء الاصطناعي. (${response.statusCode})";
    }
  }

  Future<void> _handleLLMQuery(String userQuery) async {
    _addMessage("أنت", userQuery);
    setState(() => _isLoading = true);

    // Summarize purchase orders for context with better analysis
    String ordersSummary = "";
    Map<String, int> clientOrderCount = {};
    Map<String, double> clientRevenue = {};
    Map<String, int> productCount = {};
    Map<String, int> stateCount = {};
    double totalRevenue = 0;

    for (var order in allOrders) {
      // Build detailed summary with null safety
      double quantity = ((order['quantity'] ?? 0) as num).toDouble();
      double prix = ((order['prix'] ?? 0) as num).toDouble();
      double prixPercent = ((order['prixPercent'] ?? 0) as num).toDouble();
      String state = order['state'] ?? 'غير معروف';
      
      // If prix is 0, try to calculate it from percentage (assuming base price of 10000)
      if (prix == 0.0 && prixPercent > 0) {
        prix = 10000 - (prixPercent / 100 * 10000);
      }
      
      // Calculate revenue only for completed orders (effectué)
      double orderRevenue = 0.0;
      bool isCompleted = state.toLowerCase() == 'effectué' || 
                        state.toLowerCase() == 'effectue' ||
                        state.toLowerCase() == 'validé' ||
                        state.toLowerCase() == 'valide' ||
                        state.toLowerCase() == 'validated' ||
                        state.toLowerCase() == 'completed' ||
                        state.toLowerCase() == 'true' ||
                        state == 'true' ||
                        state == '1';
      
      if (isCompleted) {
        orderRevenue = quantity * prix;
      }
      
      ordersSummary +=
          "طلب: عميل=${order['client']}, منتج=${order['product']}, كمية=${quantity}, سعر=${prix}, نسبة=${prixPercent}%, حالة=${state}, إيراد=${orderRevenue.toStringAsFixed(2)}\n";

      // Calculate statistics
      String client = order['client'] ?? 'غير معروف';
      String product = order['product'] ?? 'غير معروف';

      clientOrderCount[client] = (clientOrderCount[client] ?? 0) + 1;
      clientRevenue[client] = (clientRevenue[client] ?? 0) + orderRevenue;
      productCount[product] = (productCount[product] ?? 0) + 1;
      stateCount[state] = (stateCount[state] ?? 0) + 1;
      totalRevenue += orderRevenue;
    }

    // Generate statistics summary in Arabic
    int completedOrders = allOrders.where((order) {
      String state = order['state'] ?? '';
      return state.toLowerCase() == 'effectué' || 
             state.toLowerCase() == 'effectue' ||
             state.toLowerCase() == 'validé' ||
             state.toLowerCase() == 'valide' ||
             state.toLowerCase() == 'validated' ||
             state.toLowerCase() == 'completed' ||
             state.toLowerCase() == 'true' ||
             state == 'true' ||
             state == '1';
    }).length;
    
    // Find the date of the first order
    String firstOrderDate = 'غير متاح';
    if (allOrders.isNotEmpty) {
      final sortedOrders = allOrders.toList()..sort((a, b) {
        final aDate = a['date'] ?? '';
        final bDate = b['date'] ?? '';
        return aDate.compareTo(bDate);
      });
      firstOrderDate = sortedOrders.first['date'] ?? 'غير متاح';
    }

    String statsSummary =
        """
ملخص إحصائيات المبيعات (آخر 1000 طلب):
- إجمالي الطلبات: ${allOrders.length}
- الطلبات المكتملة: $completedOrders
- الطلبات المعلقة: ${allOrders.length - completedOrders}
- إجمالي الإيرادات (الطلبات المكتملة فقط): ${totalRevenue.toStringAsFixed(2)} دج
- تاريخ أول طلب في هذا التحليل: $firstOrderDate
- حالات الطلبات الموجودة: ${stateCount.entries.map((e) => '${e.key}: ${e.value}').join(', ')}
- أفضل 5 عملاء حسب الطلبات: ${clientOrderCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value))}
- أفضل 5 عملاء حسب الإيرادات: ${clientRevenue.entries.toList()..sort((a, b) => b.value.compareTo(a.value))}
- أفضل المنتجات: ${productCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value))}
- توزيع حالات الطلبات: ${stateCount.entries.toList()}
""";

    final prompt =
        """
أنت محلل مبيعات خبير. إليك البيانات الكاملة لأوامر الشراء والإحصائيات:

$statsSummary

البيانات التفصيلية للطلبات:
${ordersSummary.length > 8000 ? ordersSummary.substring(0, 8000) + '...[مقطوع]' : ordersSummary}

سؤال المستخدم: $userQuery

يرجى تقديم تحليل شامل باللغة العربية بناءً على البيانات أعلاه. اجعل إجابتك مهنية وتحليلية مع أرقام ونسب محددة حيثما أمكن.

مهم: احتفظ بإجابتك قصيرة ومركزة في 3-4 فقرات فقط. لا تكتب أكثر من ذلك.
""";

    _addMessage("🤖", "جاري التحليل...");
    _scrollToBottom();

    try {
      final llmResponse = await askLLM(prompt);
      setState(() {
        _messages.removeLast(); // Remove "جاري التحليل..."
        _addMessage("🤖", llmResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _addMessage(
          "🤖",
          "عذراً، حدث خطأ أثناء التحليل. يرجى المحاولة مرة أخرى.",
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void setOrders(List<Map<String, dynamic>> orders) {
    setState(() {
      allOrders = orders;
    });
  }

  double _calculateTotalRevenue() {
    double totalRevenue = 0;
    
    for (var order in allOrders) {
      double quantity = ((order['quantity'] ?? 0) as num).toDouble();
      double prix = ((order['prix'] ?? 0) as num).toDouble();
      double prixPercent = ((order['prixPercent'] ?? 0) as num).toDouble();
      String state = order['state'] ?? '';
      
      // If prix is 0, try to calculate it from percentage (assuming base price of 10000)
      if (prix == 0.0 && prixPercent > 0) {
        prix = 10000 - (prixPercent / 100 * 10000);
      }
      
      // Calculate revenue only for completed orders (effectué)
      bool isCompleted = state.toLowerCase() == 'effectué' || 
                        state.toLowerCase() == 'effectue' ||
                        state.toLowerCase() == 'validé' ||
                        state.toLowerCase() == 'valide' ||
                        state.toLowerCase() == 'validated' ||
                        state.toLowerCase() == 'completed' ||
                        state.toLowerCase() == 'true' ||
                        state == 'true' ||
                        state == '1';
      
      if (isCompleted) {
        double orderRevenue = quantity * prix;
        totalRevenue += orderRevenue;
      }
    }
    
    return totalRevenue;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildPresetQuery(String title, String query, String icon) {
    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        avatar: Text(icon, style: const TextStyle(fontSize: 16)),
        label: Text(
          title,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        onPressed: () {
          _controller.text = query;
          _handleSubmitted(query);
        },
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.red.shade200),
        elevation: 2,
        shadowColor: Colors.red.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> message, bool isBot) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isBot
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBot) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE57373), // Soft red
                    Color(0xFFD32F2F), // Medium red
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text('🤖', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isBot ? Colors.grey.shade50 : null,
                gradient: isBot
                    ? null
                    : const LinearGradient(
                        colors: [
                          Color(0xFFE57373), // Soft red
                          Color(0xFFD32F2F), // Medium red
                        ],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isBot
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                  bottomRight: isBot
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['sender']!,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isBot ? Colors.grey.shade600 : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    message['message']!,
                    style: GoogleFonts.poppins(
                      color: isBot ? Colors.black87 : Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isBot) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text('👤', style: TextStyle(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'مساعد المبيعات',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.topRight,
              colors: [
                Color(0xFFE57373), // Soft red
                Color(0xFFD32F2F), // Medium red
              ],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_outlined),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'جاري تحديث بيانات الطلبات...',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.green.shade600,
                  ),
                );
                await _fetchAllOrdersForAnalysis();
              },
              tooltip: 'تحديث الطلبات',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                setState(() {
                  _messages.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم مسح المحادثة',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.blue.shade600,
                  ),
                );
              },
              tooltip: 'مسح المحادثة',
            ),
          ),
        ],
      ),
      drawer: AppDrawer(orders: allOrders),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFEBEE), // Very light red/pink
              Color(0xFFFFCDD2), // Light red/pink
              Color(0xFFEF9A9A), // Soft red
            ],
          ),
        ),
        child: Column(
          children: [
            // Data summary header
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '${allOrders.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: allOrders.isEmpty
                              ? Colors.red.shade600
                              : Colors.blue.shade600,
                        ),
                      ),
                      Text(
                        allOrders.isEmpty ? 'لا توجد طلبات' : 'إجمالي الطلبات',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        allOrders.isEmpty
                            ? 'غير متاح'
                            : '${_calculateTotalRevenue().toStringAsFixed(0)} دج',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'إجمالي الإيرادات',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: allOrders.isEmpty
                              ? Colors.red.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          allOrders.isEmpty
                              ? Icons.error_outline
                              : Icons.analytics,
                          color: allOrders.isEmpty
                              ? Colors.red.shade600
                              : Colors.blue.shade600,
                          size: 32,
                        ),
                      ),
                      if (allOrders.isEmpty)
                        Text(
                          'اضغط للتحديث',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            color: Colors.red.shade600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Preset queries section
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _presetQueries.length,
                itemBuilder: (context, index) {
                  final preset = _presetQueries[index];
                  return _buildPresetQuery(
                    preset['title']!,
                    preset['query']!,
                    preset['icon']!,
                  );
                },
              ),
            ),

            const Divider(height: 1, color: Colors.white),

            // Messages area
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isBot = message['sender'] == '🤖';
                    return _buildMessageBubble(message, isBot);
                  },
                ),
              ),
            ),

            // Loading indicator
            if (_isLoading)
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'جاري التحليل...',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Input area
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.red.shade200),
                        color: Colors.red.shade50,
                      ),
                      child: TextField(
                        controller: _controller,
                        onSubmitted: _handleSubmitted,
                        decoration: InputDecoration(
                          hintText: "اسأل عن إحصائيات المبيعات...",
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade600,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        style: GoogleFonts.poppins(),
                        maxLines: null,
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE57373), // Soft red
                          Color(0xFFD32F2F), // Medium red
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _isLoading
                          ? null
                          : () => _handleSubmitted(_controller.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
