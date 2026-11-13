import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../domain/dates.dart';
import '../../providers.dart';
import '../common.dart';
import 'package:trainlog/i18n.dart';

/// Карточка продукта: ручной ввод на 100 г, избранное, атрибуция Open Food Facts.
/// При сохранении возвращает id продукта.
class ProductEditScreen extends ConsumerStatefulWidget {
  const ProductEditScreen({super.key, this.productId, this.initialName = '', this.barcode});
  final int? productId;
  final String initialName;
  final String? barcode;

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  late final _name = TextEditingController(text: widget.initialName);
  final _brand = TextEditingController();
  late final _barcode = TextEditingController(text: widget.barcode ?? '');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();
  Product? _product;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString().replaceAll('.', decSep);

  Future<void> _load() async {
    final id = widget.productId;
    if (id != null) {
      final p = await ref.read(nutritionRepoProvider).product(id);
      if (p != null) {
        _product = p;
        _name.text = p.name;
        _brand.text = p.brand ?? '';
        _barcode.text = p.barcode ?? '';
        _kcal.text = _fmt(p.kcal100g);
        _protein.text = _fmt(p.protein100g);
        _fat.text = _fmt(p.fat100g);
        _carbs.text = _fmt(p.carbs100g);
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    for (final c in [_name, _brand, _barcode, _kcal, _protein, _fat, _carbs]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final kcal = parseNum(_kcal.text);
    if (name.isEmpty) return toast(context, tr('Введите название'));
    if (kcal == null || kcal < 0) return toast(context, tr('Укажите калорийность на 100 г'));
    final id = await ref.read(nutritionRepoProvider).saveManualProduct(
          id: widget.productId,
          name: name,
          brand: _brand.text.trim(),
          barcode: _barcode.text.trim(),
          kcal: kcal,
          protein: parseNum(_protein.text) ?? 0,
          fat: parseNum(_fat.text) ?? 0,
          carbs: parseNum(_carbs.text) ?? 0,
        );
    if (mounted) Navigator.of(context).pop(id);
  }

  Widget _numField(TextEditingController c, String label) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: decimalInput,
            decoration: InputDecoration(labelText: label, isDense: true),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(nutritionRepoProvider);
    final p = _product;
    final live = widget.productId == null ? null : ref.watch(productProvider(widget.productId!)).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productId == null ? tr('Новый продукт') : tr('Продукт')),
        actions: [
          if (live != null)
            IconButton(
              tooltip: tr('Избранное'),
              icon: Icon(live.isFavorite ? Icons.star : Icons.star_border),
              onPressed: () => repo.setFavorite(live.id, !live.isFavorite),
            ),
          if (p != null)
            IconButton(
              tooltip: tr('Удалить'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirm(context, tr('Удалить продукт?'), message: tr('Записи дневника с ним сохранятся.'))) return;
                final ok = await repo.deleteProduct(p.id);
                if (!context.mounted) return;
                if (ok) {
                  Navigator.of(context).pop();
                } else {
                  toast(context, tr('Продукт входит в рецепт — сначала уберите его из рецепта'));
                }
              },
            ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: _name, decoration: InputDecoration(labelText: tr('Название'))),
                const SizedBox(height: 12),
                TextField(controller: _brand, decoration: InputDecoration(labelText: tr('Марка (необязательно)'))),
                const SizedBox(height: 12),
                TextField(
                  controller: _barcode,
                  enabled: p?.source != 'off',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tr('Штрихкод (необязательно)')),
                ),
                const SizedBox(height: 16),
                Text(tr('На 100 г'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(children: [_numField(_kcal, tr('Ккал')), _numField(_protein, tr('Белки, г'))]),
                const SizedBox(height: 12),
                Row(children: [_numField(_fat, tr('Жиры, г')), _numField(_carbs, tr('Углеводы, г'))]),
                const SizedBox(height: 16),
                if (p?.source == 'off')
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        tr('Источник данных: Open Food Facts (openfoodfacts.org), код {0}. '
                        'База распространяется по лицензии Open Database License (ODbL).'
                        '{1}', [p!.offCode ?? p.barcode ?? '', p.syncedAt == null ? '' : tr('\nЗагружено: {0}.', [ruDate(DateTime.fromMillisecondsSinceEpoch(p.syncedAt!))])]),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: Text(tr('Сохранить'))),
                const SizedBox(height: 8),
                Text(tr('Правка продукта не меняет уже сделанные записи дневника: в них хранится снимок КБЖУ.')),
              ],
            ),
    );
  }
}
