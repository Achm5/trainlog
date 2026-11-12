import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../data/rules_repo.dart';
import '../../domain/planning.dart';
import '../../providers.dart';
import '../common.dart';

String _pct(num v) => '${(v * 100).toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',')}%';

/// Объяснение рекомендации: факты, по которым сработало правило, и что предлагается.
String explainRecommendation(RecommendationView v) {
  final f = v.facts;
  final p = v.proposal;
  switch (p['type']) {
    case 'reduce_weight':
      final misses = (f['latest_shortfalls'] as List? ?? const []).join(', ');
      return 'Две последние сессии «${f['exercise']}» со статусом «провал»'
          '${misses.isEmpty ? '' : ' (недобор повторов в последней: $misses)'}. '
          'Предлагается снизить вес с ${formatKg((p['from_kg'] as num).toDouble())} до '
          '${formatKg((p['to_kg'] as num).toDouble())} кг (${_pct(f['pct'] as num)}, не менее 2,5 кг). '
          'Веса следующих недель сдвинутся на ${formatKg((p['delta_kg'] as num).toDouble())} кг.';
    case 'choice':
      final series = (f['e1rm_kg'] as List? ?? const []).map((e) => formatKg((e as num).toDouble())).join(' → ');
      return 'Расчётный 1ПМ «${f['exercise']}» не вырос на ${f['min_growth_pct']}% за ${f['weeks']} нед. подряд '
          '($series кг, разгрузки не учитываются). На выбор: сменить вариацию или добавить подход в неделю.';
    case 'early_deload':
      final reason = f['reason'] == 'stall'
          ? 'Без роста 1ПМ ${f['no_growth_weeks']} нед.: ${(f['stalled'] as List).join(', ')} '
              '(${(f['stalled'] as List).length} из ${f['compounds']} базовых упражнений).'
          : 'Жёлтых и красных подходов за неделю: ${_pct(f['bad_share'] as num)} '
              '(${(f['sets_partial'] as int) + (f['sets_failed'] as int)} из '
              '${(f['sets_done'] as int) + (f['sets_partial'] as int) + (f['sets_failed'] as int)}).';
      return '$reason Предлагается поставить разгрузку на неделю ${p['week_no']}, остаток цикла сдвинется.';
  }
  return v.rule.name;
}

const recStatusLabels = {'new': 'Новая', 'accepted': 'Принята', 'rejected': 'Отклонена', 'expired': 'Истекла'};

/// Карточка рекомендации с действиями. План меняется только после подтверждения.
class RecommendationCard extends ConsumerWidget {
  const RecommendationCard(this.view, {super.key});
  final RecommendationView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(rulesRepoProvider);
    final rec = view.rec;
    final proposal = view.proposal;
    final isChoice = proposal['type'] == 'choice';
    final variations = (proposal['variations'] as List? ?? const []).cast<Map<String, dynamic>>();

    Future<void> run(Future<void> Function() action, String done) async {
      try {
        await action();
        if (context.mounted) toast(context, done);
      } catch (e) {
        if (context.mounted) toast(context, 'Не удалось применить: $e');
      }
    }

    Future<void> pickVariation() async {
      final id = await showDialog<int>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Сменить вариацию на'),
          children: [
            for (final v in variations)
              SimpleDialogOption(onPressed: () => Navigator.pop(c, v['id'] as int), child: Text(v['name'] as String)),
          ],
        ),
      );
      if (id != null) {
        await run(() => repo.accept(rec.id, option: 'change_variation', variationId: id), 'Вариация изменена');
      }
    }

    return Card(
      color: rec.status == 'new' ? Theme.of(context).colorScheme.tertiaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline),
                const SizedBox(width: 8),
                Expanded(child: Text(view.rule.name, style: Theme.of(context).textTheme.titleMedium)),
                if (rec.status != 'new') Chip(label: Text(recStatusLabels[rec.status] ?? rec.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text(explainRecommendation(view)),
            const SizedBox(height: 8),
            if (rec.status == 'new')
              Wrap(
                spacing: 8,
                children: [
                  if (isChoice) ...[
                    if (variations.isNotEmpty) FilledButton(onPressed: pickVariation, child: const Text('Сменить вариацию')),
                    FilledButton.tonal(
                      onPressed: () => run(() => repo.accept(rec.id, option: 'add_sets'), 'Подход добавлен в план'),
                      child: const Text('+1 подход'),
                    ),
                  ] else
                    FilledButton(
                      onPressed: () => run(() => repo.accept(rec.id), 'Изменения записаны в план'),
                      child: const Text('Принять'),
                    ),
                  TextButton(onPressed: () => repo.reject(rec.id), child: const Text('Отклонить')),
                ],
              )
            else if (rec.status == 'accepted' && rec.previousValues != null)
              TextButton.icon(
                icon: const Icon(Icons.undo),
                label: const Text('Откатить изменения'),
                onPressed: () async {
                  if (await confirm(context, 'Откатить рекомендацию?', message: 'План вернётся к прежним значениям.')) {
                    await run(() => repo.rollback(rec.id), 'План возвращён');
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Все рекомендации с историей решений.
class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Рекомендации')),
      body: AsyncView(
        value: ref.watch(allRecommendationsProvider),
        builder: (list) => list.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Рекомендаций пока нет. Правила проверяются после каждой завершённой тренировки '
                      'и при закрытии недели.', textAlign: TextAlign.center),
                ),
              )
            : ListView(padding: const EdgeInsets.all(8), children: [for (final v in list) RecommendationCard(v)]),
      ),
    );
  }
}

/// Правила движка: включение, приоритет, cooldown и пороги (JSON) меняются без релиза.
class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  Future<void> _editJson(BuildContext context, WidgetRef ref, Rule rule, {required bool condition}) async {
    final pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(condition ? rule.condition : rule.action));
    final text = await askText(context, condition ? 'Условие (JSON)' : 'Действие (JSON)', initial: pretty, maxLines: 10);
    if (text == null) return;
    try {
      final parsed = jsonDecode(text);
      if (parsed is! Map || parsed['type'] is! String) throw const FormatException();
      final value = Value(jsonEncode(parsed));
      await ref
          .read(rulesRepoProvider)
          .updateRule(rule.id, condition ? RulesCompanion(condition: value) : RulesCompanion(action: value));
    } catch (_) {
      if (context.mounted) toast(context, 'Некорректный JSON: нужен объект с полем "type"');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(rulesRepoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Правила')),
      body: AsyncView(
        value: ref.watch(rulesProvider),
        builder: (rules) => ListView(
          children: [
            for (final r in rules)
              ExpansionTile(
                title: Text(r.name),
                subtitle: Text('${r.code} · приоритет ${r.priority} · пауза ${r.cooldownDays} дн.'),
                leading: Switch(
                  value: r.isActive,
                  onChanged: (v) => repo.updateRule(r.id, RulesCompanion(isActive: Value(v))),
                ),
                children: [
                  ListTile(
                    title: const Text('Приоритет'),
                    trailing: Text('${r.priority}'),
                    onTap: () async {
                      final v = await askNumber(context, 'Приоритет', initial: r.priority.toDouble(), integer: true);
                      if (v != null) await repo.updateRule(r.id, RulesCompanion(priority: Value(v.round())));
                    },
                  ),
                  ListTile(
                    title: const Text('Пауза перед повторным срабатыванием'),
                    trailing: Text('${r.cooldownDays} дн.'),
                    onTap: () async {
                      final v = await askNumber(context, 'Пауза, дней', initial: r.cooldownDays.toDouble(), integer: true);
                      if (v != null && v >= 0) await repo.updateRule(r.id, RulesCompanion(cooldownDays: Value(v.round())));
                    },
                  ),
                  ListTile(
                    title: const Text('Условие'),
                    subtitle: Text(r.condition),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editJson(context, ref, r, condition: true),
                  ),
                  ListTile(
                    title: const Text('Действие'),
                    subtitle: Text(r.action),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editJson(context, ref, r, condition: false),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
