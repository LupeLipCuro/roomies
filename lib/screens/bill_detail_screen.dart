import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../utils/split.dart';

/// Detalle de una cuenta.
/// - Si eres quien la registró: ves el estado de cada roomie y validas comprobantes.
/// - Si eres roomie: ves tu parte, a quién transferir y subes tu comprobante.
class BillDetailScreen extends StatefulWidget {
  const BillDetailScreen({super.key, required this.billId, required this.user, required this.group});
  final String billId;
  final User user;
  final Group group;

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  final _data = DataService();
  bool _busy = false;

  Future<void> _uploadProof(Bill bill) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (x == null) return;
    setState(() => _busy = true);
    try {
      await _data.uploadProof(bill: bill, uid: widget.user.uid, file: File(x.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comprobante enviado. Quedó "Por validar".')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo subir: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showImage(String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Bill?>(
      stream: _data.bill(widget.billId),
      builder: (context, snap) {
        final bill = snap.data;
        if (bill == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        final iAmPayer = bill.payerId == widget.user.uid;
        return Scaffold(
          appBar: AppBar(title: Text(bill.concept)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Header(bill: bill, iAmPayer: iAmPayer),
              if (bill.invoiceUrl != null)
                TextButton.icon(onPressed: () => _showImage(bill.invoiceUrl!), icon: const Icon(Icons.receipt_long_outlined), label: const Text('Ver factura')),
              const SizedBox(height: 12),
              if (iAmPayer) ..._payerView(bill) else ..._debtorView(bill),
            ],
          ),
        );
      },
    );
  }

  // ---------- Vista de quien registró la cuenta ----------
  List<Widget> _payerView(Bill bill) {
    final others = bill.splits.where((s) => s.uid != bill.payerId).toList();
    return [
      const Text('Pagos de tus roomies', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final s in others)
        Card(
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(widget.group.members[s.uid] ?? 'Roomie', style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(formatSoles(s.amountCents), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              _StatusChip(s.status),
              if (s.status == PayStatus.review) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => _showImage(s.proofUrl!), child: const Text('Ver comprobante'))),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)), onPressed: () => _data.confirmPayment(bill.id, s.uid), child: const Text('Confirmar'))),
                ]),
                TextButton(onPressed: () => _data.rejectProof(bill.id, s.uid), child: const Text('Rechazar comprobante')),
              ],
            ]),
          ),
        ),
    ];
  }

  // ---------- Vista de quien debe ----------
  List<Widget> _debtorView(Bill bill) {
    final mine = bill.splitOf(widget.user.uid);
    if (mine == null) return [const Text('No participas en esta cuenta.')];
    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tu parte', style: TextStyle(color: Colors.white)),
          Text(formatSoles(mine.amountCents), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700)),
          Text('${mine.percent.toStringAsFixed(mine.percent % 1 == 0 ? 0 : 1)}% de ${formatSoles(bill.totalCents)}', style: const TextStyle(color: Colors.white)),
        ]),
      ),
      const SizedBox(height: 16),
      FutureBuilder<Map<String, dynamic>?>(
        future: _data.userProfile(bill.payerId),
        builder: (context, snap) {
          final pay = snap.data?['payInfo'] as String?;
          return Card(
            elevation: 0,
            color: Colors.white,
            child: ListTile(
              title: Text('Transfiere a ${bill.payerName}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(pay == null || pay.isEmpty ? 'Aún no registró sus datos de pago. Pídeselos.' : pay),
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      _StatusChip(mine.status),
      if (mine.proofUrl != null) TextButton(onPressed: () => _showImage(mine.proofUrl!), child: const Text('Ver mi comprobante')),
      const SizedBox(height: 12),
      if (mine.status != PayStatus.paid)
        FilledButton.icon(
          onPressed: _busy ? null : () => _uploadProof(bill),
          icon: const Icon(Icons.upload),
          label: Text(mine.status == PayStatus.review ? 'Subir otro comprobante' : 'Subir comprobante de transferencia'),
        ),
      const SizedBox(height: 8),
      const Text('Quien registró la cuenta revisará tu comprobante y confirmará el pago.', style: TextStyle(fontSize: 12, color: Colors.black54)),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.bill, required this.iAmPayer});
  final Bill bill;
  final bool iAmPayer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE4E0D6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Total de la factura', style: TextStyle(color: Colors.black54, fontSize: 13)),
        Text(formatSoles(bill.totalCents), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          '${iAmPayer ? 'Registraste tú' : 'Registró ${bill.payerName}'} · vence ${DateFormat('d MMM yyyy', 'es').format(bill.dueDate)}',
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final PayStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PayStatus.pending => ('Pendiente', const Color(0xFF8A4205)),
      PayStatus.review => ('Por validar', kTeal),
      PayStatus.paid => ('Pagado', kTeal),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}
