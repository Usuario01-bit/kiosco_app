import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'sales_screen.dart';
import 'students_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'pending_screen.dart';
import 'admin_screen.dart';
import 'login_screen.dart';
import '../services/database_helper.dart';
import '../services/theme_provider.dart';
import '../services/responsive.dart';


class HomeScreen extends StatefulWidget {

  final String username;
  final String role;

  const HomeScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {

  int selectedIndex = 0;

  bool get isSuperAdmin => widget.role == 'super_admin';

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

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            R.sp(context, 24),
            R.sp(context, 16),
            R.sp(context, 24),
            R.sp(context, 24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              SizedBox(height: R.sp(context, 20)),

              Row(
                children: [
                  CircleAvatar(
                    child: Icon(Icons.person, size: R.sp(context, 28)),
                  ),
                  SizedBox(width: R.sp(context, 16)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.username,
                        style: TextStyle(
                          fontSize: R.fs(context, 20),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isSuperAdmin ? 'Super Admin' : 'Administrador',
                        style: TextStyle(
                          fontSize: R.fs(context, 16),
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: R.sp(context, 24)),
              const Divider(),
              SizedBox(height: R.sp(context, 8)),

              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Cambiar contraseña'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showChangePassword();
                },
              ),

              if (isSuperAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Gestionar administradores'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminScreen()),
                    );
                  },
                ),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangePassword() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña actual',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar nueva contraseña',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: Colors.red),
                );
                return;
              }
              if (newCtrl.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mínimo 4 caracteres'), backgroundColor: Colors.red),
                );
                return;
              }
              try {
                final ok = await DatabaseHelper.instance.changePassword(
                  widget.username,
                  oldCtrl.text,
                  newCtrl.text,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Contraseña cambiada' : 'Contraseña actual incorrecta'),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ),
                );
              } catch (e) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final screens = [

      const DashboardScreen(),

      SalesScreen(),

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
                  right: 8,
                  bottom: 4,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.settings,
                  ),
                  onPressed: _showSettings,
                  tooltip: 'Configuración',
                ),
              ),
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

            icon: Icon(Icons.people),

            label: 'Alumnos',
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