import 'package:flutter/material.dart';
import 'category_page.dart';
import 'product_page.dart';
import 'addon_page.dart';
import 'order_page.dart';
import 'table_page.dart';
import 'pos_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Modern sleek background
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        toolbarHeight: 80,
        title: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.teal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Foodie Admin Portal',
                style: TextStyle(
                  color: Color(0xFF1E293B), // Dark slate color
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 32.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: () {},
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200, width: 2),
                  ),
                  child: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    radius: 18,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Banner
                Container(
                  width: double.infinity,
                  height: 220,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F766E),
                        Color(0xFF14B8A6),
                      ], // Sleek Teal gradients
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Decorative background icon
                      Positioned(
                        right: -20,
                        top: -40,
                        child: Icon(
                          Icons.fastfood,
                          size: 250,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Welcome back, Admin!',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Manage your restaurant\'s categories, products, and add-ons seamlessly.',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.teal.shade50,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 56),

                const Text(
                  'Dashboard Management',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Grid of Actions
                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 4;
                    if (constraints.maxWidth < 1000) crossAxisCount = 3;
                    if (constraints.maxWidth < 800) crossAxisCount = 2;
                    if (constraints.maxWidth < 500) crossAxisCount = 1;

                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 32,
                      mainAxisSpacing: 32,
                      childAspectRatio: 0.95,
                      children: [
                        _HoverDashboardCard(
                          title: 'Categories',
                          subtitle: 'Organize your menu structure',
                          icon: Icons.category_rounded,
                          color: Colors.orange,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CategoryPage(),
                            ),
                          ),
                        ),
                        _HoverDashboardCard(
                          title: 'Products',
                          subtitle: 'Manage items & update prices',
                          icon: Icons.fastfood_rounded,
                          color: Colors.blue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProductPage(),
                            ),
                          ),
                        ),
                        _HoverDashboardCard(
                          title: 'Add-ons',
                          subtitle: 'Configure extra toppings & sides',
                          icon: Icons.extension_rounded,
                          color: Colors.teal,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddonPage(),
                            ),
                          ),
                        ),
                        _HoverDashboardCard(
                          title: 'Orders',
                          subtitle: 'Process & track incoming orders',
                          icon: Icons.receipt_long_rounded,
                          color: Colors.purple,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OrderPage(),
                            ),
                          ),
                        ),
                        _HoverDashboardCard(
                          title: 'Tables',
                          subtitle: 'Manage dining tables',
                          icon: Icons.table_restaurant_rounded,
                          color: Colors.red,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TablePage(),
                            ),
                          ),
                        ),
                        _HoverDashboardCard(
                          title: 'POS System',
                          subtitle: 'Point of sale interface',
                          icon: Icons.point_of_sale_rounded,
                          color: Colors.indigo,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PosPage(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverDashboardCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final MaterialColor color;
  final VoidCallback onTap;

  const _HoverDashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HoverDashboardCard> createState() => _HoverDashboardCardState();
}

class _HoverDashboardCardState extends State<_HoverDashboardCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _isHovered ? -8 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.grey.shade100, width: 2),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.color.withOpacity(0.2)
                    : Colors.black.withOpacity(0.04),
                blurRadius: _isHovered ? 30 : 15,
                offset: _isHovered ? const Offset(0, 15) : const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isHovered ? widget.color : widget.color.shade50,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: widget.color.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    widget.icon,
                    size: 40,
                    color: _isHovered ? Colors.white : widget.color.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
