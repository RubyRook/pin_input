import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

sealed class PinInputController {
  final int length;

  PinInputController({required this.length})
      : assert(length > 0, 'Pin length must be at least 1!');

  final message = ValueNotifier<String?>(null);

  Future<String> pinResult() async =>
      throw UnimplementedError('pinResult has not been implemented.');

  Future<void> changePinLength() async =>
      throw UnimplementedError('changePinLength has not been implemented.');

  Future<void> onError(String message) async =>
      throw UnimplementedError('onError has not been implemented.');

  Future<void> clearError() async =>
      throw UnimplementedError('clearError has not been implemented.');

  Future<void> unfocus(BuildContext context) async =>
      FocusScope.of(context).unfocus();

  factory PinInputController.init(int length){
    if (Platform.isIOS) {
      return PinInputIos(length: length);
    } else {
      return PinInputAndroid(length: length);
    }
  }
}

final class PinInputIos extends PinInputController {
  PinInputIos({required super.length});

  int? id;
  final channelName = 'pin_input_field';

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
  Future<void> changePinLength() async {
    if (id case int viewId when Platform.isIOS) {
      final channel = MethodChannel("${channelName}_$viewId");
      await channel.invokeMethod('changePinLength');
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
  Future<void> clearError() async {
    if (id case int viewId when Platform.isIOS) {
      message.value = '';

      final channel = MethodChannel("${channelName}_$viewId");
      await channel.invokeMethod('clearErrorState');
    }
  }

  @override
  Future<void> unfocus(BuildContext context) async {
    if (id case int viewId when Platform.isIOS) {
      final channel = MethodChannel("${channelName}_$viewId");
      await channel.invokeMethod('unfocus');
    }
  }
}

final class PinInputAndroid extends PinInputController {
  PinInputAndroid({required super.length});

  final focusNode = FocusNode();
}
