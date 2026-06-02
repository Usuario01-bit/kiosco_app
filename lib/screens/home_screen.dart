import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'sales_screen.dart';
import 'students_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'pending_screen.dart';
import '../services/theme_provider.dart';


class HomeScreen extends StatefulWidget {

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {

  int selectedIndex = 0;

  // =========================
  // ESTUDIANTES
  // =========================

  @override
  void initState() {

    super.initState();

    ThemeProvider.instance.addListener(_refresh);
  }

  @override
  void dispose() {

    ThemeProvider.instance.removeListener(_refresh);

    super.dispose();
  }

  void _refresh() {

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {

    final List<Widget> screens = [

      const DashboardScreen(),

      const SalesScreen(),

      const StudentsScreen(),

      const ProductsScreen(),

      const ReportsScreen(),

      const PendingScreen(),
    ];

    return Scaffold(

      body: screens[selectedIndex],

      bottomNavigationBar:
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment:
            MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  right: 12,
                  bottom: 4,
                ),
                child: IconButton(
                  icon: Icon(
                    ThemeProvider
                        .instance.isDark
                        ? Icons
                        .dark_mode
                        : Icons
                        .light_mode,
                  ),
                  onPressed: () {
                    ThemeProvider
                        .instance
                        .toggle();
                  },
                  tooltip: 'Modo oscuro',
                ),
              ),
            ],
          ),
          NavigationBar(

        selectedIndex: selectedIndex,

        onDestinationSelected:
            (index) {

          setState(() {

            selectedIndex = index;
          });
        },

        destinations: const [

          NavigationDestination(

            icon: Icon(Icons.home),

            label: 'Inicio',
          ),

          NavigationDestination(

            icon:
            Icon(Icons.point_of_sale),

            label: 'Ventas',
          ),

          NavigationDestination(

            icon: Icon(Icons.groups),

            label: 'Estudiantes',
          ),

          NavigationDestination(

            icon:
            Icon(Icons.inventory_2),

            label: 'Productos',
          ),

          NavigationDestination(

            icon:
            Icon(Icons.bar_chart),

            label: 'Reportes',
          ),

          NavigationDestination(

            icon:
            Icon(Icons.pending_actions),

            label: 'Pendientes',
          ),
        ],
      ),
        ],
      ),
    );
  }
}