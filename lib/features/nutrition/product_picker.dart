import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/database.dart';
import '../../domain/dates.dart';
import '../../domain/nutrition.dart';
import '../../providers.dart';
import '../../services/off_client.dart';
import '../common.dart';
import 'product_edit.dart';

/// Выбор продукта для записи в дневник: избранное и недавние, свои продукты,
/// поиск в Open Food Facts по названию и штрихкоду.
class ProductPickerScreen extends ConsumerStatefulWidget {
  const ProductPickerScreen({super.key, required this.day, required this.meal});
  final DateTime day;
  final String meal;

  @override
  ConsumerState<ProductPickerScreen> createState() => _ProductPickerScreenState();
}

class _ProductPickerScreenState extends ConsumerState<ProductPickerScreen> {
  final _search = TextEditingController();
  String _query = '';
  List<OffProduct>? _offResults;
  String? _offError;
  bool _offLoading = false;
  List<Product> _recent = const [];

  @override
  void initState() {
    super.initState();
    ref.read(nutritionRepoProvider).recentProducts().then((r) {
      if (mounted) setState(() => _recent = r);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add(Product p) async {
    final grams = await askNumber(context, '${p.name}: сколько граммов?', initial: 100, suffix: 'г');
    if (grams == null || grams <= 0) return;
    await ref.read(nutritionRepoProvider).addFood(date: widget.day, meal: widget.meal, product: p, grams: grams);
    if (mounted) {
      toast(context, 'Добавлено: ${p.name}, ${grams.round()} г');
      Navigator.of(context).pop();
    }
  }

  Future<void> _addOff(OffProduct p) async {
    final repo = ref.read(nutritionRepoProvider);
    final id = await repo.cacheOffProduct(p);
    final saved = await repo.product(id);
    if (saved != null && mounted) await _add(saved);
  }

  Future<void> _searchOff() async {
    final q = _query.trim();
    if (q.length < 2) return toast(context, 'Введите название продукта');
    setState(() {
      _offLoading = true;
      _offError = null;
      _offResults = null;
    });
    try {
      final r = await ref.read(offClientProvider).search(q);
      if (mounted) setState(() => _offResults = r);
    } on OffException catch (e) {
      if (mounted) setState(() => _offError = e.message);
    } finally {
      if (mounted) setState(() => _offLoading = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const BarcodeScanScreen()));
    if (code == null || !mounted) return;
    final repo = ref.read(nutritionRepoProvider);
    final local = await repo.byBarcode(code);
    if (local != null) {
      if (mounted) await _add(local);
      return;
    }
    try {
      final r = await ref.read(offClientProvider).byBarcode(code);
      if (!mounted) return;
      if (r.product != null) {
        await _addOff(r.product!);
        return;
      }
      toast(context, r.found
          ? 'В карточке Open Food Facts нет калорий — заполните продукт вручную'
          : 'Штрихкод $code не найден — добавьте продукт вручную');
      await _createManual(barcode: code);
    } on OffException catch (e) {
      if (!mounted) return;
      toast(context, e.message);
      await _createManual(barcode: code);
    }
  }

  Future<void> _createManual({String? barcode}) async {
    final id = await Navigator.of(context).push<int>(
        MaterialPageRoute(builder: (_) => ProductEditScreen(initialName: barcode == null ? _query : '', barcode: barcode)));
    if (id == null || !mounted) return;
    final p = await ref.read(nutritionRepoProvider).product(id);
    if (p != null && mounted) await _add(p);
  }

  Widget _tile(Product p) => ListTile(
        dense: true,
        leading: Icon(p.isFavorite ? Icons.star : (p.source == 'recipe' ? Icons.restaurant_menu : Icons.fastfood_outlined)),
        title: Text(p.brand == null ? p.name : '${p.name} · ${p.brand}'),
        subtitle: Text('${p.kcal100g.round()} ккал · Б ${p.protein100g.round()} Ж ${p.fat100g.round()} У ${p.carbs100g.round()} на 100 г'),
        trailing: IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<int>(builder: (_) => ProductEditScreen(productId: p.id))),
        ),
        onTap: () => _add(p),
      );

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider(_query)).value ?? const <Product>[];
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${mealLabels[widget.meal]} · ${ruDate(widget.day)}'),
        actions: [
          IconButton(tooltip: 'Сканировать штрихкод', icon: const Icon(Icons.qr_code_scanner), onPressed: _scan),
          IconButton(tooltip: 'Новый продукт вручную', icon: const Icon(Icons.add), onPressed: _createManual),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Название продукта', isDense: true),
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (_) => _searchOff(),
            ),
          ),
          if (_query.isEmpty && _recent.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text('Недавние', style: t.titleSmall)),
            for (final p in _recent.take(8)) _tile(p),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_query.isEmpty ? 'Избранное и сохранённые' : 'Сохранённые продукты', style: t.titleSmall),
          ),
          if (products.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('Сохранённых продуктов не найдено')),
          for (final p in products) _tile(p),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: FilledButton.tonalIcon(
              onPressed: _offLoading ? null : _searchOff,
              icon: const Icon(Icons.public),
              label: Text(_offLoading ? 'Ищу…' : 'Искать в Open Food Facts'),
            ),
          ),
          if (_offError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_offError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_offResults != null && _offResults!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ничего не найдено (карточки без калорий не показываются). Добавьте продукт вручную.'),
            ),
          for (final p in _offResults ?? const <OffProduct>[])
            ListTile(
              dense: true,
              leading: const Icon(Icons.public),
              title: Text(p.brand == null ? p.name : '${p.name} · ${p.brand}'),
              subtitle: Text('${p.kcal100.round()} ккал · Б ${p.protein100.round()} Ж ${p.fat100.round()} У ${p.carbs100.round()} на 100 г'),
              onTap: () => _addOff(p),
            ),
          if (_offResults != null && _offResults!.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Данные: Open Food Facts (openfoodfacts.org), лицензия Open Database License (ODbL).'),
            ),
        ],
      ),
    );
  }
}

/// Сканер штрихкода камерой. Возвращает строку кода.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Наведите камеру на штрихкод')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          for (final b in capture.barcodes) {
            final v = b.rawValue;
            if (v != null && RegExp(r'^\d{8,14}$').hasMatch(v)) {
              _done = true;
              Navigator.of(context).pop(v);
              return;
            }
          }
        },
      ),
    );
  }
}
