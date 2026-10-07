import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalesReportPage extends StatelessWidget {
  const SalesReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Sales Report Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sales').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Calculate Aggregates
          double totalRevenue = 0;
          double totalCash = 0;
          double totalCredit = 0;
          
          double dineIn = 0;
          double takeaway = 0;
          double driveThrough = 0;
          double delivery = 0;

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              double amount = double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0;
              double cash = double.tryParse(data['cashAmount']?.toString() ?? '0') ?? 0;
              double credit = double.tryParse(data['creditAmount']?.toString() ?? '0') ?? 0;
              String type = data['orderType'] ?? '';

              totalRevenue += amount;
              totalCash += cash;
              totalCredit += credit;

              if (type == 'Dine In') dineIn += amount;
              else if (type == 'Takeaway') takeaway += amount;
              else if (type == 'Drive Through') driveThrough += amount;
              else if (type == 'Delivery') delivery += amount;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Revenue Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Total Revenue',
                        amount: totalRevenue,
                        icon: Icons.monetization_on,
                        gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Total Cash',
                        amount: totalCash,
                        icon: Icons.money,
                        gradient: const LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF22C55E)]),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Total Credit',
                        amount: totalCredit,
                        icon: Icons.credit_card,
                        gradient: const LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                const Text('Revenue by Order Type', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _buildTypeCard('Dine In', dineIn, Icons.table_restaurant, Colors.teal)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildTypeCard('Takeaway', takeaway, Icons.shopping_bag, Colors.orange)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildTypeCard('Drive Through', driveThrough, Icons.directions_car, Colors.purple)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildTypeCard('Delivery', delivery, Icons.local_shipping, Colors.blue)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({required String title, required double amount, required IconData icon, required Gradient gradient}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
              Icon(icon, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 16),
          Text('\$${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTypeCard(String title, double amount, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade100, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.shade50, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Color(0xFF475569), fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 32),
          Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
