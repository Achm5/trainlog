import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/app_state.dart';
import '../../providers.dart';
import '../../services/security.dart';

/// Блокировка при запуске: если задан PIN, приложение открывается после PIN или биометрии.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> {
  final _pin = TextEditingController();
  final _bio = BiometricService();
  bool _unlocked = false;
  bool _bioEnabled = false;
  bool _bioTried = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    if (await _bio.authenticate() && mounted) setState(() => _unlocked = true);
  }

  Future<void> _initBiometric() async {
    if (_bioTried) return;
    _bioTried = true;
    final enabled = await ref.read(appStateProvider).get(stateBiometricEnabled) == '1' && await _bio.available();
    if (!mounted || !enabled) return;
    setState(() => _bioEnabled = true);
    await _tryBiometric();
  }

  void _check(String hash) {
    if (pinHash(_pin.text) == hash) {
      setState(() => _unlocked = true);
    } else {
      setState(() => _error = 'Неверный PIN');
      _pin.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final hash = settings.pinHash;
    if (hash == null || _unlocked) return widget.child;
    _initBiometric();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                Text('Введите PIN', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: _pin,
                  autofocus: true,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(errorText: _error, counterText: ''),
                  onSubmitted: (_) => _check(hash),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => _check(hash), child: const Text('Войти')),
                if (_bioEnabled)
                  TextButton.icon(
                    onPressed: _tryBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Биометрия'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
