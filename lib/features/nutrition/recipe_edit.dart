import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../domain/nutrition.dart';
import '../../providers.dart';
import '../common.dart';

/// Рецепт из нескольких продуктов. КБЖУ на 100 г считается из ингредиентов.
/// При сохранении возвращает id продукта-рецепта.
class RecipeEditScreen extends ConsumerStatefulWidget {
  const RecipeEditScreen({super.key, this.recipeId});
  final int? recipeId;

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  final _name = TextEditingController();
  final _items = <int, (Product, double)>{};
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    () async {
      final id = widget.recipeId;
      if (id != null) {
        final repo = ref.read(nutritionRepoProvider);
        _name.text = (await repo.product(id))?.name ?? '';
        for (final i in await repo.recipeItems(id)) {
          _items[i.product.id] = (i.product, i.grams);
        }
      }
      if (mounted) setState(() => _ready = true);
    }();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addIngredient() async {
    final p = await Navigator.of(context).push<Product>(MaterialPageRoute(builder: (_) => _IngredientPicker(exclude: widget.recipeId)));
    if (p == null || !mounted) return;
    final g = await askNumber(context, '${p.name}: граммы', initial: _items[p.id]?.$2 ?? 100, suffix: 'г');
    if (g != null && g > 0) setState(() => _items[p.id] = (p, g));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return toast(context, 'Введите название рецепта');
    if (_items.isEmpty) return toast(context, 'Добавьте хотя бы один ингредиент');
    final id = await ref
        .read(nutritionRepoProvider)
        .saveRecipe(id: widget.recipeId, name: name, gramsByProductId: {for (final e in _items.entries) e.key: e.value.$2});
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final r = recipePer100([
      for (final (p, g) in _items.values)
        RecipeIngredient(grams: g, kcal100: p.kcal100g, protein100: p.protein100g, fat100: p.fat100g, carbs100: p.carbs100g),
    ]);
    return Scaffold(
      appBar: AppBar(title: Text(widget.recipeId == null ? 'Новый рецепт' : 'Рецепт')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Название рецепта')),
                const SizedBox(height: 16),
                Text('Ингредиенты', style: Theme.of(context).textTheme.titleSmall),
                for (final e in _items.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value.$1.name),
                    subtitle: Text('${e.value.$2.round()} г · ${(e.value.$1.kcal100g * e.value.$2 / 100).round()} ккал'),
                    trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _items.remove(e.key))),
                    onTap: () async {
                      final g = await askNumber(context, 'Граммы', initial: e.value.$2, suffix: 'г');
                      if (g != null && g > 0) setState(() => _items[e.key] = (e.value.$1, g));
                    },
                  ),
                OutlinedButton.icon(onPressed: _addIngredient, icon: const Icon(Icons.add), label: const Text('Добавить ингредиент')),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Общий вес: ${r.totalGrams.round()} г\n'
                        'На 100 г: ${r.kcal.round()} ккал · Б ${r.protein.toStringAsFixed(1)} · '
                        'Ж ${r.fat.toStringAsFixed(1)} · У ${r.carbs.toStringAsFixed(1)}'),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: const Text('Сохранить рецепт')),
                const SizedBox(height: 8),
                const Text('Вес рецепта считается как сумма ингредиентов. Если поправить продукт-ингредиент, '
                    'откройте и сохраните рецепт заново, чтобы пересчитать его КБЖУ.'),
              ],
            ),
    );
  }
}

class _IngredientPicker extends ConsumerStatefulWidget {
  const _IngredientPicker({this.exclude});
  final int? exclude;

  @override
  ConsumerState<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends ConsumerState<_IngredientPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final list = (ref.watch(productsProvider(_query)).value ?? const <Product>[])
        .where((p) => p.source != 'recipe' && p.id != widget.exclude)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Ингредиент')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Сохранённые продукты', isDense: true),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Нет сохранённых продуктов. Сначала добавьте продукты вручную или из Open Food Facts.',
                          textAlign: TextAlign.center),
                    ),
                  )
                : ListView(
                    children: [
                      for (final p in list)
                        ListTile(
                          title: Text(p.name),
                          subtitle: Text('${p.kcal100g.round()} ккал на 100 г'),
                          onTap: () => Navigator.of(context).pop(p),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
