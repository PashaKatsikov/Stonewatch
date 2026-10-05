import 'dart:ffi';

import '../core/stonewatch_core.dart';

/// Round randomness, owned by the Rust core. Freed by [close] or, if the
/// owner forgets, by the native finalizer when this object is collected.
final class Dice implements Finalizable {
  Dice([int? seed]) : _handle = swDiceNew(seed ?? _freshSeed()) {
    _finalizer.attach(this, _handle, detach: this);
  }

  static final NativeFinalizer _finalizer = NativeFinalizer(
    Native.addressOf<NativeFunction<Void Function(Pointer<Void>)>>(swDiceFree),
  );

  static int _issued = 0;

  static int _freshSeed() {
    _issued++;
    return DateTime.now().microsecondsSinceEpoch ^
        (_issued * 0x5851F42D4C957F2D);
  }

  Pointer<Void> _handle;

  /// Uniform in `[0, 1)`.
  double unit() => swDiceUnit(_handle);

  /// Uniform in `[0, n)`.
  int below(int n) => swDiceBelow(_handle, n);

  int roundId() => swDiceRoundId(_handle);

  /// A block index different from [art] whenever [count] allows it.
  int otherThan(int art, int count) => swDiceOtherThan(_handle, art, count);

  void close() {
    if (_handle == nullptr) return;
    _finalizer.detach(this);
    swDiceFree(_handle);
    _handle = nullptr;
  }
}
