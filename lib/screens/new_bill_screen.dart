import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/data_service.dart';
import '../utils/split.dart';

/// Registrar una cuenta compartida: partes iguales (por defecto) o por porcentajes.
class NewBillScreen extends StatefulWidget {
  const NewBillScreen({super.key, required this.user, required this.group});
  final User user;
  final Group group;

  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen> {
  final _data = DataService();
  final _concept = TextEditingController();
  final _amount = TextEditingController();
  late final List<String> _ids = widget.group.members.keys.toList();
  late final Map<String, TextEditingController> _pct = {for (final id in _ids) id: TextEditingController()};
  DateTime _due = DateTime.now().add(const Duration(days: 7));
  bool _byPercent = false;
  File? _invoice;
  bool _busy = false;

  @override
  void dispose() {
    _concept.dispose();
    _amount.dispose();
    for (final c in _pct.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _total => parseCents(_amount.text) ?? 0;

  List<double> get _percents => _byPercent
      ? _ids.map((id) => double.tryParse(_pct[id]!.text.replaceAll(',', '.')) ?? 0).toList()
      : List.filled(_ids.length, 100 / _ids.length);

  /// Montos por persona o null si los porcentajes no suman 100.
  List<int>? get _amounts => _byPercent ? splitByPercent(_total, _percents) : splitEqual(_total, _ids.length);

  double get _percentSum => _percents.fold(0, (a, b) => a + b);

  Future<void> _pickInvoice() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (x != null) setState(() => _invoice = File(x.path));
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _due = d);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_concept.text.trim().isEmpty) return messenger.showSnackBar(const SnackBar(content: Text('Escribe el concepto (luz, agua, internet…)')));
    if (_total <= 0) return messenger.showSnackBar(const SnackBar(content: Text('Ingresa un monto válido')));
    final amounts = _amounts;
    if (amounts == null) return messenger.showSnackBar(const SnackBar(content: Text('Los porcentajes deben sumar 100%')));

    setState(() => _busy = true);
    try {
      await _data.createBill(
        group: widget.group,
        payer: widget.user,
        concept: _concept.text,
        totalCents: _total,
        dueDate: _due,
        memberIds: _ids,
        amounts: amounts,
        percents: _percents,
        invoice: _invoice,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amounts = _amounts;
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva cuenta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          TextField(controller: _concept, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Concepto')),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto total (S/)'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Vence el'),
                  child: Text(DateFormat('d MMM yyyy', 'es').format(_due)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickInvoice,
            icon: const Icon(Icons.attach_file),
            label: Text(_invoice == null ? 'Adjuntar foto de la factura' : 'Factura adjuntada (cambiar)'),
          ),
          const SizedBox(height: 20),
          const Text('¿Cómo se divide?', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Partes iguales')),
              ButtonSegment(value: true, label: Text('Porcentajes')),
            ],
            selected: {_byPercent},
            onSelectionChanged: (s) => setState(() => _byPercent = s.first),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _ids.length; i++)
            Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      _ids[i] == widget.user.uid ? '${widget.group.members[_ids[i]]} (tú)' : widget.group.members[_ids[i]] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_byPercent)
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _pct[_ids[i]],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(suffixText: '%', isDense: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    )
                  else
                    Text('${(100 / _ids.length).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 84,
                    child: Text(
                      amounts == null ? '—' : formatSoles(amounts[i]),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),
            ),
          if (_byPercent)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                amounts == null ? 'Los porcentajes suman ${_percentSum.toStringAsFixed(1)}% (deben sumar 100%)' : 'Los porcentajes suman 100%',
                style: TextStyle(color: amounts == null ? const Color(0xFFB3261E) : const Color(0xFF0B5A54), fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Registrar cuenta'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Se asume que tú pagaste la factura al proveedor: tu parte queda como pagada y tus roomies te transfieren la suya.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
