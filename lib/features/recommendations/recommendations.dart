import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../data/rules_repo.dart';
import '../../domain/planning.dart';
import '../../providers.dart';
import '../common.dart';
import 'package:trainlog/i18n.dart';

String _pct(num v) => '${(v * 100).toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', decSep)}%';

/// Объяснение рекомендации: факты, по которым сработало правило, и что предлагается.
String explainRecommendation(RecommendationView v) {
  final f = v.facts;
  final p = v.proposal;
  switch (p['type']) {
    case 'reduce_weight':
      final misses = (f['latest_shortfalls'] as List? ?? const []).join(', ');
      return tr('Две последние сессии «{0}» со статусом «провал»'
          '{1}. '
          'Предлагается снизить вес с {2} до '
          '{3} кг ({4}). '
          'Веса следующих недель сдвинутся на {5} кг.', [_ex(f), misses.isEmpty ? '' : tr(' (недобор повторов в последней: {0})', [misses]), formatKg((p['from_kg'] as num).toDouble()), formatKg((p['to_kg'] as num).toDouble()), _pct(f['pct'] as num), formatKg((p['delta_kg'] as num).toDouble())]);
    case 'increase_weight':
      final why = f['reason'] == 'top_of_range'
          ? tr('сделан верх диапазона повторов во всех рабочих подходах')
          : tr('запас RIR не меньше {0} сверх целевого', [f['rir_margin']]);
      return tr('Последние {0} сессии «{1}» выполнены полностью: {2}. '
          'Предлагается прибавить вес с {3} до '
          '{4} кг ({5}). '
          'Веса следующих недель сдвинутся на +{6} кг.', [f['sessions'], _ex(f), why, formatKg((p['from_kg'] as num).toDouble()), formatKg((p['to_kg'] as num).toDouble()), _pct(f['pct'] as num), formatKg((p['delta_kg'] as num).toDouble())]);
    case 'reduce_reps':
      final misses = (f['latest_shortfalls'] as List? ?? const []).join(', ');
      return tr('Последние {0} сессии «{1}» выполнены частично'
          '{2}. '
          'Предлагается оставить вес и снизить повторы: {3}–{4} → '
          '{5}–{6} во всех следующих неделях.', [f['sessions'], _ex(f), misses.isEmpty ? '' : tr(' (недобор повторов в последней: {0})', [misses]), p['from_min'], p['from_max'], p['to_min'], p['to_max']]);
    case 'choice':
      final series = (f['e1rm_kg'] as List? ?? const []).map((e) => formatKg((e as num).toDouble())).join(' → ');
      return tr('Расчётный 1ПМ «{0}» не вырос на {1}% за {2} нед. подряд '
          '({3} кг, разгрузки не учитываются). На выбор: сменить вариацию или добавить подход в неделю.', [_ex(f), f['min_growth_pct'], f['weeks'], series]);
    case 'early_deload':
      final reason = f['reason'] == 'stall'
          ? tr('Без роста 1ПМ {0} нед.: {1} '
              '({2} из {3} базовых упражнений).', [f['no_growth_weeks'], (f['stalled'] as List).map((e) => trName('$e')).join(', '), (f['stalled'] as List).length, f['compounds']])
          : tr('Жёлтых и красных подходов за неделю: {0} '
              '({1} из '
              '{2}).', [_pct(f['bad_share'] as num), (f['sets_partial'] as int) + (f['sets_failed'] as int), (f['sets_done'] as int) + (f['sets_partial'] as int) + (f['sets_failed'] as int)]);
      return tr('{0} Предлагается поставить разгрузку на неделю {1}, остаток цикла сдвинется.', [reason, p['week_no']]);
  }
  return trName(v.rule.name);
}

String _ex(Map<String, dynamic> facts) => trName('${facts['exercise'] ?? ''}');

Map<String, String> get recStatusLabels => {'new': tr('Новая'), 'accepted': tr('Принята'), 'rejected': tr('Отклонена'), 'expired': tr('Истекла')};

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
        if (context.mounted) toast(context, tr('Не удалось применить: {0}', [e]));
      }
    }

    Future<void> pickVariation() async {
      final id = await showDialog<int>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text(tr('Сменить вариацию на')),
          children: [
            for (final v in variations)
              SimpleDialogOption(onPressed: () => Navigator.pop(c, v['id'] as int), child: Text(trName(v['name'] as String))),
          ],
        ),
      );
      if (id != null) {
        await run(() => repo.accept(rec.id, option: 'change_variation', variationId: id), tr('Вариация изменена'));
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
                Expanded(child: Text(trName(view.rule.name), style: Theme.of(context).textTheme.titleMedium)),
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
                    if (variations.isNotEmpty) FilledButton(onPressed: pickVariation, child: Text(tr('Сменить вариацию'))),
                    FilledButton.tonal(
                      onPressed: () => run(() => repo.accept(rec.id, option: 'add_sets'), tr('Подход добавлен в план')),
                      child: Text(tr('+1 подход')),
                    ),
                  ] else
                    FilledButton(
                      onPressed: () => run(() => repo.accept(rec.id), tr('Изменения записаны в план')),
                      child: Text(tr('Принять')),
                    ),
                  TextButton(onPressed: () => repo.reject(rec.id), child: Text(tr('Отклонить'))),
                ],
              )
            else if (rec.status == 'accepted' && rec.previousValues != null)
              TextButton.icon(
                icon: const Icon(Icons.undo),
                label: Text(tr('Откатить изменения')),
                onPressed: () async {
                  if (await confirm(context, tr('Откатить рекомендацию?'), message: tr('План вернётся к прежним значениям.'))) {
                    await run(() => repo.rollback(rec.id), tr('План возвращён'));
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
      appBar: AppBar(title: Text(tr('Рекомендации'))),
      body: AsyncView(
        value: ref.watch(allRecommendationsProvider),
        builder: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(tr('Рекомендаций пока нет. Правила проверяются после каждой завершённой тренировки '
                      'и при закрытии недели.'), textAlign: TextAlign.center),
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
    final text = await askText(context, condition ? tr('Условие (JSON)') : tr('Действие (JSON)'), initial: pretty, maxLines: 10);
    if (text == null) return;
    try {
      final parsed = jsonDecode(text);
      if (parsed is! Map || parsed['type'] is! String) throw const FormatException();
      final value = Value(jsonEncode(parsed));
      await ref
          .read(rulesRepoProvider)
          .updateRule(rule.id, condition ? RulesCompanion(condition: value) : RulesCompanion(action: value));
    } catch (_) {
      if (context.mounted) toast(context, tr('Некорректный JSON: нужен объект с полем "type"'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(rulesRepoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Правила'))),
      body: AsyncView(
        value: ref.watch(rulesProvider),
        builder: (rules) => ListView(
          children: [
            for (final r in rules)
              ExpansionTile(
                title: Text(trName(r.name)),
                subtitle: Text(tr('{0} · приоритет {1} · пауза {2} дн.', [r.code, r.priority, r.cooldownDays])),
                leading: Switch(
                  value: r.isActive,
                  onChanged: (v) => repo.updateRule(r.id, RulesCompanion(isActive: Value(v))),
                ),
                children: [
                  ListTile(
                    title: Text(tr('Приоритет')),
                    trailing: Text('${r.priority}'),
                    onTap: () async {
                      final v = await askNumber(context, tr('Приоритет'), initial: r.priority.toDouble(), integer: true);
                      if (v != null) await repo.updateRule(r.id, RulesCompanion(priority: Value(v.round())));
                    },
                  ),
                  ListTile(
                    title: Text(tr('Пауза перед повторным срабатыванием')),
                    trailing: Text(tr('{0} дн.', [r.cooldownDays])),
                    onTap: () async {
                      final v = await askNumber(context, tr('Пауза, дней'), initial: r.cooldownDays.toDouble(), integer: true);
                      if (v != null && v >= 0) await repo.updateRule(r.id, RulesCompanion(cooldownDays: Value(v.round())));
                    },
                  ),
                  ListTile(
                    title: Text(tr('Условие')),
                    subtitle: Text(r.condition),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editJson(context, ref, r, condition: true),
                  ),
                  ListTile(
                    title: Text(tr('Действие')),
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
