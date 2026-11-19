import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../utils/split.dart';
import 'bill_detail_screen.dart';
import 'new_bill_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user, required this.group});
  final User user;
  final Group group;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _data = DataService();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _monthKey => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final uid = widget.user.uid;
    final monthLabel = toBeginningOfSentenceCase(DateFormat('MMMM yyyy', 'es').format(_month));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(tooltip: 'Roomies', icon: const Icon(Icons.group_outlined), onPressed: _showRoomies),
          IconButton(tooltip: 'Mis datos de pago', icon: const Icon(Icons.account_balance_wallet_outlined), onPressed: _editPayInfo),
          IconButton(tooltip: 'Cerrar sesión', icon: const Icon(Icons.logout), onPressed: () => AuthService().signOut()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva cuenta'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NewBillScreen(user: widget.user, group: widget.group)),
        ),
      ),
      body: StreamBuilder<List<Bill>>(
        stream: _data.billsOfGroup(widget.group.id),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final bills = snap.data!.where((b) => b.month == _monthKey).toList();

          var owe = 0, owed = 0;
          for (final b in bills) {
            for (final s in b.splits) {
              if (s.status == PayStatus.paid) continue;
              if (b.payerId != uid && s.uid == uid) owe += s.amountCents;
              if (b.payerId == uid && s.uid != uid) owed += s.amountCents;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(tooltip: 'Mes anterior', onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left)),
                Text(monthLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(tooltip: 'Mes siguiente', onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right)),
              ]),
              Row(children: [
                Expanded(child: _SummaryCard(label: 'Tú debes', value: formatSoles(owe), color: const Color(0xFF8A4205), filled: false)),
                const SizedBox(width: 12),
                Expanded(child: _SummaryCard(label: 'Te deben', value: formatSoles(owed), color: kTeal, filled: true)),
              ]),
              const SizedBox(height: 20),
              const Text('Cuentas del mes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (bills.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Aún no hay cuentas este mes.\nToca "Nueva cuenta" para registrar la primera.', textAlign: TextAlign.center)),
                ),
              for (final b in bills) _BillTile(bill: b, uid: uid, onTap: () => _open(b)),
            ],
          );
        },
      ),
    );
  }

  void _open(Bill b) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BillDetailScreen(billId: b.id, user: widget.user, group: widget.group)),
      );

  void _showRoomies() {
    final email = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Roomies', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final e in widget.group.members.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(e.value.isNotEmpty ? e.value[0].toUpperCase() : '?')),
                title: Text(e.key == widget.user.uid ? '${e.value} (tú)' : e.value),
                subtitle: e.key == widget.group.ownerId ? const Text('Administrador/a') : null,
              ),
            const Divider(),
            const Text('Invitar por correo'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'correo@ejemplo.com'),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(90, 52)),
                onPressed: () async {
                  final value = email.text.trim();
                  if (!value.contains('@')) return;
                  await _data.inviteByEmail(group: widget.group, email: value, by: widget.user);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Invitación creada para $value. Podrá unirse al iniciar sesión con ese correo.'),
                    ));
                  }
                },
                child: const Text('Invitar'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _editPayInfo() async {
    final profile = await _data.userProfile(widget.user.uid) ?? {};
    final pay = TextEditingController(text: profile['payInfo'] as String? ?? '');
    final phone = TextEditingController(text: profile['phone'] as String? ?? '');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mis datos de pago'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: pay, decoration: const InputDecoration(labelText: 'Yape, Plin o cuenta para recibir pagos')),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Celular')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () async {
              await _data.updatePaymentInfo(widget.user.uid, payInfo: pay.text, phone: phone.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.color, required this.filled});
  final String label;
  final String value;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: filled ? color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: filled ? null : Border.all(color: const Color(0xFFE4E0D6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, color: filled ? Colors.white : Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.bill, required this.uid, required this.onTap});
  final Bill bill;
  final String uid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mine = bill.splitOf(uid);
    final iAmPayer = bill.payerId == uid;
    final review = bill.splits.where((s) => s.uid != bill.payerId && s.status == PayStatus.review).length;
    final pendingOthers = bill.splits.where((s) => s.uid != bill.payerId && s.status != PayStatus.paid).length;

    String chip;
    Color chipColor;
    if (iAmPayer) {
      if (review > 0) {
        chip = '$review por validar';
        chipColor = kTeal;
      } else if (pendingOthers > 0) {
        chip = '$pendingOthers pendiente(s)';
        chipColor = const Color(0xFF8A4205);
      } else {
        chip = 'Todo cobrado';
        chipColor = kTeal;
      }
    } else {
      switch (mine?.status ?? PayStatus.pending) {
        case PayStatus.paid:
          chip = 'Pagado';
          chipColor = kTeal;
        case PayStatus.review:
          chip = 'Por validar';
          chipColor = kTeal;
        case PayStatus.pending:
          chip = 'Por pagar';
          chipColor = const Color(0xFF8A4205);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE4E0D6))),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(bill.concept, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${iAmPayer ? 'Registraste tú' : 'Registró ${bill.payerName}'} · ${formatSoles(bill.totalCents)} · vence ${DateFormat('d MMM', 'es').format(bill.dueDate)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (!iAmPayer && mine != null) Text(formatSoles(mine.amountCents), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(chip, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: chipColor)),
          ),
        ]),
      ),
    );
  }
}
