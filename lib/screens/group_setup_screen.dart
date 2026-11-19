import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';

/// Se muestra cuando la persona aún no pertenece a ningún grupo:
/// puede aceptar una invitación recibida (por su correo) o crear un grupo nuevo.
class GroupSetupScreen extends StatefulWidget {
  const GroupSetupScreen({super.key, required this.user});
  final User user;

  @override
  State<GroupSetupScreen> createState() => _GroupSetupScreenState();
}

class _GroupSetupScreenState extends State<GroupSetupScreen> {
  final _data = DataService();
  final _name = TextEditingController();
  bool _busy = false;

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await _data.createGroup(_name.text, widget.user);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear el grupo: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.user.email;
    return Scaffold(
      appBar: AppBar(
        actions: [IconButton(tooltip: 'Cerrar sesión', onPressed: () => AuthService().signOut(), icon: const Icon(Icons.logout))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Hola, ${widget.user.displayName ?? 'roomie'}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Únete al grupo de tu depa o crea uno nuevo.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          if (email != null)
            StreamBuilder<List<Invite>>(
              stream: _data.pendingInvites(email),
              builder: (context, snap) {
                final invites = snap.data ?? [];
                if (invites.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Invitaciones para ti', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final i in invites)
                      Card(
                        child: ListTile(
                          title: Text(i.groupName),
                          subtitle: Text('Te invitó ${i.invitedBy}'),
                          trailing: FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
                            onPressed: () => _data.acceptInvite(i, widget.user),
                            child: const Text('Unirme'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          const Text('Crear un grupo', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre del grupo (ej. Depa Miraflores)')),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _create, child: const Text('Crear grupo')),
          const SizedBox(height: 8),
          const Text('Después podrás invitar a tus roomies por correo.', style: TextStyle(color: Colors.black54, fontSize: 13)),
        ],
      ),
    );
  }
}
