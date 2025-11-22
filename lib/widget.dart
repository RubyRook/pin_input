import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_input/extension.dart';
import 'package:pin_input/pin_input_method_channel.dart';

final class WidgetData {
  final double size;
  final double spacing;
  final Color? backgroundColor;
  final Color? cursorColor;
  final Color? invalidColor;
  final Color? fontColor;
  final double fontSize;
  final FontWeight fontWeight;

  final Color? defaultBorderColor;
  final Color? focusedBorderColor;

  final double cornerRadius;
  final double focusedBorderWidth;

  WidgetData({
    this.size = 54,
    this.spacing = 12,
    this.backgroundColor,
    this.cursorColor,
    this.invalidColor,
    this.fontColor,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w400,
    this.defaultBorderColor,
    this.focusedBorderColor,
    this.cornerRadius = 8,
    this.focusedBorderWidth = 1,
  })
      : assert(size >= 44, 'Pin text field size must be at least 44!');
}

class PinInputField extends StatelessWidget {
  final PinInputController controller;
  final double size;
  final double spacing;
  final Color? backgroundColor;
  final Color? cursorColor;
  final Color? invalidColor;
  final Color? fontColor;
  final double fontSize;
  final FontWeight fontWeight;

  final Color? defaultBorderColor;
  final Color? focusedBorderColor;

  final double cornerRadius;
  final double focusedBorderWidth;

  final VoidCallback? onEditingComplete;
  final Widget Function(BuildContext context, String? errorText)? errorBuilder;

  const PinInputField({
    super.key,
    required this.controller,
    this.size = 54,
    this.spacing = 12,
    this.backgroundColor,
    this.cursorColor,
    this.invalidColor,
    this.fontColor,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w400,
    this.defaultBorderColor,
    this.focusedBorderColor,
    this.cornerRadius = 8,
    this.focusedBorderWidth = 1,
    this.errorBuilder,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    final widgetData = WidgetData(
      size: size,
      spacing: spacing,
      backgroundColor: backgroundColor,
      cursorColor: cursorColor,
      invalidColor: invalidColor,
      fontColor: fontColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      defaultBorderColor: defaultBorderColor,
      focusedBorderColor: focusedBorderColor,
      cornerRadius: cornerRadius,
      focusedBorderWidth: focusedBorderWidth,
    );

    if (controller case PinInputIos ctrl) {
      return _PinInputFieldIos(
        controller: ctrl,
        data: widgetData,
        errorBuilder: errorBuilder,
      );
    }
    else if (controller case PinInputAndroid ctrl) {
      return _PinInputFieldAndroid(
        controller: ctrl,
        data: widgetData,
        errorBuilder: errorBuilder,
      );
    }

    throw UnimplementedError('Unsupported platform!');
  }
}

class _PinInputFieldIos extends StatelessWidget {
  final PinInputIos controller;
  final WidgetData data;
  final Widget Function(BuildContext context, String? errorText)? errorBuilder;

  const _PinInputFieldIos({
    required this.controller,
    required this.data,
    this.errorBuilder,
  });

  void _onPlatformViewCreated(int id) {
    controller.id = id;

    final channel = MethodChannel('${controller.channelName}_$id');
    channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'pinResult') {
        final result = await channel.invokeMethod('pinResult');
        print("pinResult: $result");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      "pinLength": controller.length,
      "size": data.size,
      "spacing": data.spacing,
      "backgroundColor": ?data.backgroundColor?.toHex(),
      "cursorColor": ?data.backgroundColor?.toHex(),
      "invalidColor": ?data.invalidColor?.toHex(),

      "fontColor": ?data.fontColor?.toHex(),
      "fontSize": data.fontSize,
      "fontWeight": data.fontWeight.value,

      "defaultBorderColor": ?data.defaultBorderColor?.toHex(),
      "focusedBorderColor": ?data.focusedBorderColor?.toHex(),

      "cornerRadius": data.cornerRadius,
      "focusedBorderWidth": data.focusedBorderWidth,
    };

    return Column(
      children: [
        SizedBox(
          height: data.size,
          child: UiKitView(
            viewType: controller.channelName,
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          ),
        ),
        if (errorBuilder case final errorBuilder?) ValueListenableBuilder(
          valueListenable: controller.message,
          builder: (context, value, _) => errorBuilder(context, value),
        ),
      ],
    );
  }
}

class _PinInputFieldAndroid extends StatelessWidget {
  final PinInputAndroid controller;
  final WidgetData data;
  final Widget Function(BuildContext context, String? errorText)? errorBuilder;

  const _PinInputFieldAndroid({
    required this.controller,
    required this.data,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: data.size,
          child: KeyboardListener(
            focusNode: controller.focusNode,
            child: Container(),
          ),
        ),
        if (errorBuilder case final errorBuilder?) ValueListenableBuilder(
          valueListenable: controller.message,
          builder: (context, value, _) => errorBuilder(context, value),
        ),
      ],
    );
  }
}