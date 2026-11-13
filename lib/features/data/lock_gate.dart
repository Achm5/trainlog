import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/app_state.dart';
import '../../providers.dart';
import '../../services/security.dart';
import 'pin_pad.dart';
import 'package:trainlog/i18n.dart';

/// Блокировка при запуске: если задан PIN, приложение открывается после PIN или биометрии.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> {
  final _bio = BiometricService();
  String _pin = '';
  bool _unlocked = false;
  bool _bioEnabled = false;
  bool _bioTried = false;
  bool _error = false;

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

  /// Длина PIN неизвестна (хранится только хэш), поэтому проверяем после каждой цифры начиная с четвёртой.
  void _digit(String d, String hash) {
    if (_pin.length >= 8) return;
    final next = _pin + d;
    if (next.length >= 4 && pinHash(next) == hash) {
      setState(() => _unlocked = true);
      return;
    }
    if (next.length == 8) {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _error = true;
      });
      return;
    }
    setState(() {
      _pin = next;
      _error = false;
    });
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40),
                const SizedBox(height: 12),
                Text(_error ? tr('Неверный PIN') : tr('Введите PIN'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: _error ? Theme.of(context).colorScheme.error : null)),
                const SizedBox(height: 24),
                PinDots(length: _pin.length, error: _error),
                const SizedBox(height: 24),
                PinPad(
                  onDigit: (d) => _digit(d, hash),
                  onBackspace: () => setState(() {
                    _error = false;
                    if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
                  }),
                  extra: _bioEnabled
                      ? IconButton(
                          iconSize: 36,
                          tooltip: tr('Биометрия'),
                          icon: const Icon(Icons.fingerprint),
                          onPressed: _tryBiometric,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
