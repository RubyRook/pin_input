import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_input/extension.dart';

part 'model.dart';
part 'widget.dart';

final _placeHolder = '_';

sealed class PinInputController {
  PinInputController({required int length}):assert(length > 0, 'Pin length must be at least 1!') {
    _length = length;
  }

  late int _length;
  int get length => _length;
  
  final message = ValueNotifier<String?>(null);

  /// Android only
  void onCodeReceive(String? code) {

  }

  void Function()? onEditingComplete;

  FutureOr<String> pinResult() async =>
      throw UnimplementedError('pinResult has not been implemented.');

  FutureOr<void> changePinLength(int newLength) async =>
      throw UnimplementedError('changePinLength has not been implemented.');

  FutureOr<void> onError(String message) async =>
      throw UnimplementedError('onError has not been implemented.');

  FutureOr<void> unfocus(BuildContext context) async =>
      FocusScope.of(context).unfocus();

  void _dispose() => throw UnimplementedError('_dispose has not been implemented.');

  factory PinInputController.init(int length){
    if (Platform.isIOS) {
      return PinInputIos(length: length);
    } else {
      return PinInputAndroid(length: length);
    }
  }
}

final class PinInputIos extends PinInputController {
  PinInputIos({required super.length}){
    _listener ??= AppLifecycleListener(onStateChange: (value) {
      // print('$value-listener\n------->');
      if (value == AppLifecycleState.paused) _unfocus();
    },);
  }

  int? id;
  final channelName = 'pin_input_field';

  AppLifecycleListener? _listener;

  Future<void> didChangePlatformBrightness(Map<String, dynamic> colorsParams) async {
    if (id case int viewId when Platform.isIOS) {
      final channel = MethodChannel("${channelName}_$viewId");
      await channel.invokeMethod('didChangePlatformBrightness', colorsParams);
    }
  }

  Future<void> _unfocus() async {
    if (id case int viewId when Platform.isIOS) {
      final channel = MethodChannel("${channelName}_$viewId");
      await channel.invokeMethod('unfocus');
    }
  }

  @override
  Future<String> pinResult() async {
    if (id case int viewId when Platform.isIOS) {
      final channel = MethodChannel("${channelName}_$viewId");
      final result = await channel.invokeMethod<String>('pinResult');
      if (result is String) return result;
    }

    return '';
  }

  @override
  Future<void> changePinLength(int newLength) async {
    if (id case int viewId when Platform.isIOS) {
      final channel = MethodChannel("${channelName}_$viewId");
      await channel.invokeMethod('changePinLength', {'pinLength': newLength});
    }
  }

  @override
  Future<void> onError(String message) async {
    if (id case int viewId when Platform.isIOS) {
      this.message.value = message;

      final channel = MethodChannel("${channelName}_$viewId");
      await channel.invokeMethod('onError', {'message': message});
    }
  }

  @override
  Future<void> unfocus(BuildContext context) async {
    await _unfocus();
  }

  @override
  void _dispose() {
    _listener?.dispose();
  }
}

final class PinInputAndroid extends PinInputController {
  PinInputAndroid({required super.length}) {
    _init();
  }

  List<Pin> _pins = [];
  
  void _init() {
    for (int i = 0; i < length; i++) {
      _pins.add(Pin());
    }
  }

  @override
  void onCodeReceive(String? code) {
    if (code != null) {
      debugPrint('onCodeReceive: $code');

      requestFocus();

      final listCode = code.split('');

      for (int i = 0; i < listCode.length; i++) {
        if (i <= length) {
          final val = listCode[i];
          _pins[i].controller.text = '$_placeHolder$val';
        }
      }

      if (listCode.length >= length) {
        FocusManager.instance.primaryFocus?.unfocus();
        onEditingComplete?.call();
      }
    }
  }

  @override
  String pinResult() {
    String text = '';

    for (int i = 0; i < length; i++) {
      final val = _pins[i].controller.text.replaceAll(_placeHolder, '');
      if (val.isNotEmpty) text += val;
    }

    return text;
  }

  @override
  void changePinLength(int newLength) {
    message.value = null;

    for (final pin in _pins) {
      pin.dispose();
    }

    _length = newLength;
    _pins = [];
    _init();
  }

  @override
  void onError(String message) {
    this.message.value = message;
  }

  @override
  void _dispose() {
    for (final pin in _pins) {
      pin.dispose();
    }

    message.dispose();
  }

  /// Request first pin focus if available
  void requestFocus()=> _pins.firstOrNull?.focusNode.requestFocus();
}
