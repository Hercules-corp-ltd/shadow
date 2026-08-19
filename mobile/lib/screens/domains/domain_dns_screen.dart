import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/domain.dart';
import '../../services/domain_service.dart';
import '../../services/fetch_outcome.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/load_state_view.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

class DomainDnsScreen extends StatefulWidget {
  const DomainDnsScreen({super.key, required this.domain});
  final String domain;

  @override
  State<DomainDnsScreen> createState() => _DomainDnsScreenState();
}

class _DomainDnsScreenState extends State<DomainDnsScreen> {
  final _service = DomainService();
  List<DnsRecord> _records = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _delete(DnsRecord r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this record?'),
        content: Text('${r.type} ${r.name} will stop resolving.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteDnsRecord(widget.domain, r.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not delete that record: $e');
      return;
    }
    if (!mounted) return;
    setState(() => _error = null);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _records = await _service.dnsRecords(widget.domain);
    } catch (e) {
      // The DNS routes do not exist on the backend at all, so this is the
      // normal path today. Showing an empty list invited the user to add
      // records into a void; showing the failure at least tells the truth.
      _records = const [];
      _error = e is DioException
          ? describeDioFailure(e)
          : 'Could not load DNS records';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'DNS Records',
      subtitle: widget.domain,
      body: Column(
        children: [
          Expanded(
            child: LoadStateView(
              isLoading: _loading,
              isEmpty: _records.isEmpty,
              error: _error,
              onRetry: _load,
              emptyIcon: Icons.dns_rounded,
              emptyTitle: 'No DNS records',
              emptyMessage:
                  'Add records to resolve subdomains, mail, or verification TXTs.',
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 12),
                itemBuilder: (_, i) {
                  final r = _records[i];
                  return GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ShadowColors.recessDeep,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color:
                                  ShadowColors.primary.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(r.type,
                              style: ShadowTypography.caption.copyWith(
                                color: ShadowColors.primary,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name, style: ShadowTypography.body),
                              Text(r.value,
                                  style: ShadowTypography.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Text('${r.ttl}s', style: ShadowTypography.caption),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: ShadowColors.error),
                          tooltip: 'Delete this record',
                          // There was no try/catch here. deleteDnsRecord
                          // throws on any non-2xx, the exception went nowhere,
                          // _load() never ran, and the row stayed on screen —
                          // so the record looked deleted-but-stubborn rather
                          // than not-deleted. This file's own comment says the
                          // DNS routes do not exist on the backend, which means
                          // that was the outcome every single time.
                          onPressed: () => _delete(r),
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: _records.length,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ShadowButton(
            label: 'Add record',
            leading: Icons.add_rounded,
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddDnsSheet(
        domain: widget.domain,
        onSave: _load,
      ),
    );
  }
}

class _AddDnsSheet extends StatefulWidget {
  const _AddDnsSheet({required this.domain, required this.onSave});
  final String domain;
  final VoidCallback onSave;

  @override
  State<_AddDnsSheet> createState() => _AddDnsSheetState();
}

class _AddDnsSheetState extends State<_AddDnsSheet> {
  final _nameCtrl = TextEditingController(text: '@');
  final _valueCtrl = TextEditingController();
  String _type = 'A';
  int _ttl = 3600;
  final _service = DomainService();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add DNS record', style: ShadowTypography.h3),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final t in const ['A', 'AAAA', 'CNAME', 'TXT', 'MX'])
                ChoiceChip(
                  label: Text(t),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'Name (@, www, ...)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _valueCtrl,
            decoration: const InputDecoration(hintText: 'Value'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('TTL'),
              const SizedBox(width: 12),
              for (final t in const [300, 3600, 86400])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${t}s'),
                    selected: _ttl == t,
                    onSelected: (_) => setState(() => _ttl = t),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ShadowButton(
            label: _saving ? 'Saving...' : 'Save record',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.upsertDnsRecord(
        widget.domain,
        DnsRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: _type,
          name: _nameCtrl.text.trim(),
          value: _valueCtrl.text.trim(),
          ttl: _ttl,
        ),
      );
      if (mounted) Navigator.of(context).pop();
      widget.onSave();
    } catch (e) {
      // There was no catch here at all, only try/finally — so a failed save
      // threw an unhandled async exception while the sheet closed anyway,
      // and the record appeared to have been created.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is DioException
                ? 'Could not save: ${describeDioFailure(e)}'
                : 'Could not save that record',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
