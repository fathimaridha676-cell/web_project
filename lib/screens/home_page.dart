import 'package:flutter/material.dart';
import 'category_page.dart';
import 'product_page.dart';
import 'addon_page.dart';
import 'order_page.dart';
import 'table_page.dart';
import 'pos_page.dart';
import 'sales_report_page.dart';
import 'sales_history_page.dart';
import 'package:flutter/foundation.dart'; // Used to check if the platform is Windows
import '../services/printer_service.dart'; // Helper to fetch and save printer config
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:permission_handler/permission_handler.dart';

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
                // Conditionally display the print icon only if the app is running on Windows or Android
                if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.android)
                  IconButton(
                    icon: const Icon(
                      Icons.print_rounded,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () async {
                      if (defaultTargetPlatform == TargetPlatform.android) {
                        // --- ANDROID: Bluetooth & USB Setup ---
                        
                        // 1. Request Runtime Permissions
                        // Android strictly requires these to be granted by the user at runtime
                        // 1. Request Runtime Permissions
                        await [
                          Permission.location,
                          Permission.bluetoothScan,
                          Permission.bluetoothConnect,
                        ].request();
                        // 2. Start Scanning (Intelligent Fallback)
                        final plugin = FlutterThermalPrinter.instance;
                        
                        // We run the scans in the background so the dialog can pop open immediately
                        Future(() async {
                          try {
                            // 1. Scan for USB printers first. This is highly reliable.
                            await plugin.getPrinters(connectionTypes: [ConnectionType.USB]);
                          } catch (e) {
                            print("DEBUG: USB Scan failed - $e");
                          }
                          
                          // Wait for 1.5 seconds to allow the USB printer to be found and sent to the UI
                          await Future.delayed(const Duration(milliseconds: 1500));
                          
                          try {
                            // 2. Now attempt BLE. If this crashes (like on your iMin device), 
                            // it won't affect the USB printer we already found!
                            await plugin.getPrinters(connectionTypes: [ConnectionType.BLE]);
                          } catch (e) {
                            print("DEBUG: BLE Scan failed (Likely permission denied by OS) - $e");
                          }
                        });

                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (context) {
                              // Local list to permanently store any printer we find, so they don't disappear!
                              List<Printer> accumulatedPrinters = [];
                              
                              return AlertDialog(
                                title: const Text('Select Printer (USB & Bluetooth)'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: StreamBuilder<List<Printer>>(
                                    stream: plugin.devicesStream,
                                    builder: (context, snapshot) {
                                      // If the stream found printers, add them to our permanent list
                                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                        for (var p in snapshot.data!) {
                                          // Ensure we don't add duplicates
                                          if (!accumulatedPrinters.any((existing) => (existing.address == p.address && existing.vendorId == p.vendorId))) {
                                            accumulatedPrinters.add(p);
                                          }
                                        }
                                      }
                                      
                                      // If we haven't found ANY printers yet, show the loader
                                      if (accumulatedPrinters.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Center(child: CircularProgressIndicator()),
                                        );
                                      }
                                      
                                      final printers = accumulatedPrinters;
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: printers.length,
                                        itemBuilder: (context, index) {
                                          final printer = printers[index];
                                          return ListTile(
                                            leading: Icon(printer.connectionType == ConnectionType.USB ? Icons.usb : Icons.bluetooth),
                                            title: Text(printer.name ?? 'Unknown Device'),
                                            subtitle: Text(printer.connectionType == ConnectionType.USB ? 'USB Printer' : (printer.address ?? '')),
                                            // --- NEW TEST BUTTON ---
                                            trailing: TextButton.icon(
                                              onPressed: () async {
                                                // 1. Show loading state so the user knows it's doing something
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Testing ${printer.name}...')),
                                                );
                                                
                                                // 2. Call the new test print function with the full printer object
                                                final error = await PrinterService.testAndroidPrint(printer);
                                                
                                                if (context.mounted) {
                                                  // 3. Display success or error
                                                  if (error == null) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Test Print Successful!'), backgroundColor: Colors.green),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text(error), backgroundColor: Colors.red),
                                                    );
                                                  }
                                                }
                                              },
                                              icon: const Icon(Icons.print, size: 18),
                                              label: const Text('TEST'),
                                            ),
                                            onTap: () async {
                                              await PrinterService.setAndroidPrinter(printer);
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Android Printer saved: ${printer.name}')),
                                                );
                                              }
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      } else {
                        // --- WINDOWS: Network/USB Setup ---
                        // Fetch the currently saved printer name using our centralized service
                        String currentPrinter = await PrinterService.getPrinterName();

                        // Use a TextEditingController to pre-fill the text field and get user input
                        TextEditingController printerController =
                            TextEditingController(text: currentPrinter);

                        // Ensure the widget is still mounted before showing the dialog after the async call
                        if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Printer Configuration'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Explanatory text for the admin
                                  const Text(
                                    'Enter the name of the printer',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: printerController,
                                    decoration: const InputDecoration(
                                      labelText: 'Printer Name',
                                      border: OutlineInputBorder(),
                                      hintText: 'e.g., EPSON_TM_T20II',
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                // Cancel button to dismiss without saving
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                // Save button to persist the value
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                  ),
                                  onPressed: () async {
                                    // Save the new printer name using our centralized service
                                    await PrinterService.setPrinterName(
                                      printerController.text.trim(),
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(
                                        context,
                                      ); // Close the dialog
                                      // Show a success message
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Printer configured successfully!',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Save',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      }
                      }
                    },
                  ),
                // Add spacing if the print icon is displayed
                if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.android)
                  const SizedBox(width: 16),
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
                            MaterialPageRoute(builder: (_) => const PosPage()),
                          ),
                        ),
                        _HoverDashboardCard(
                          title: 'Sales Report',
                          subtitle: 'View revenue insights',
                          icon: Icons.bar_chart_rounded,
                          color: Colors.green,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SalesReportPage(),
                            ),
                          ),
                        ),
                        _HoverDashboardCard(
                          title: 'Sales History',
                          subtitle: 'View recent transactions',
                          icon: Icons.history_rounded,
                          color: Colors.cyan,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SalesHistoryPage(),
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
