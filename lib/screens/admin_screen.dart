import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/responsive.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    final data = await SupabaseService.instance.getAdminUsers();
    setState(() {
      users = data;
      loading = false;
    });
  }

  void _showAddUser() {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar administrador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(
                labelText: 'Usuario',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
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
              if (userCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Completá todos los campos'), backgroundColor: Colors.red),
                );
                return;
              }
              if (passCtrl.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contraseña mínimo 8 caracteres'), backgroundColor: Colors.red),
                );
                return;
              }
              try {
                await SupabaseService.instance.createAdminUser(userCtrl.text.trim(), passCtrl.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                await loadUsers();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Usuario ${userCtrl.text.trim()} creado')),
                );
              } catch (e) {
                final msg = e.toString().contains('UNIQUE')
                    ? 'El usuario ya existe'
                    : 'Error: $e';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> user) async {
    if (user['role'] == 'super_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede eliminar al Super Admin'), backgroundColor: Colors.red),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Seguro que querés eliminar a "${user['username']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService.instance.deleteAdminUser(user['id']);
      await loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administradores'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadUsers,
              child: ListView.builder(
                padding: EdgeInsets.all(R.sp(context, 20)),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isSuper = user['role'] == 'super_admin';
                  return Container(
                    margin: EdgeInsets.only(bottom: R.sp(context, 12)),
                    padding: EdgeInsets.all(R.sp(context, 18)),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isSuper ? Colors.amber.shade100 : Colors.blue.shade100,
                          child: Icon(
                            isSuper ? Icons.star : Icons.person,
                            color: isSuper ? Colors.amber.shade700 : Colors.blue,
                          ),
                        ),
                        SizedBox(width: R.sp(context, 16)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['username'],
                                style: TextStyle(
                                  fontSize: R.fs(context, 20),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isSuper ? 'Super Admin' : 'Administrador',
                                style: TextStyle(
                                  fontSize: R.fs(context, 16),
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isSuper)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(user),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUser,
        child: const Icon(Icons.add),
      ),
    );
  }
}
