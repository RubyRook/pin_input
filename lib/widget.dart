part of 'pin_input_method_channel.dart';

final _defaultBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(8),
  borderSide: BorderSide(color: Colors.grey),
);

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


// --> iOS <--
class _PinInputFieldIos extends StatefulWidget {
  final PinInputIos controller;
  final WidgetData data;
  final Widget Function(BuildContext context, String? errorText)? errorBuilder;

  const _PinInputFieldIos({
    required this.controller,
    required this.data,
    this.errorBuilder,
  });

  @override
  State<_PinInputFieldIos> createState() => _PinInputFieldIosState();
}

class _PinInputFieldIosState extends State<_PinInputFieldIos> with WidgetsBindingObserver {
  late final controller = widget.controller;

  WidgetData get data => widget.data;

  Map<String, dynamic> get _colorsParams => {
    "backgroundColor": ?data.backgroundColor?.toHex(),
    "cursorColor": ?data.cursorColor?.toHex(),
    "defaultBorderColor": ?data.defaultBorderColor?.toHex(),
    "focusedBorderColor": ?data.focusedBorderColor?.toHex(),
    "fontColor": ?data.fontColor?.toHex(),
    "invalidColor": ?data.invalidColor?.toHex(),
  };

  void _onPlatformViewCreated(int id) {
    controller.id = id;

    final channel = MethodChannel('${controller.channelName}_$id');
    channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'pinResult') {
        final result = await channel.invokeMethod('pinResult');
        controller.onEditingComplete?.call();
        debugPrint("Pin result: $result");
      }
      else if (call.method == 'clearErrorState') {
        controller.message.value = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    controller._dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    debugPrint("$this: dispose");
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    Future.delayed(const Duration(milliseconds: 400), (){
      controller.didChangePlatformBrightness(_colorsParams);
    },);
  }

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      "pinLength": controller.length,
      "size": data.size,
      "spacing": data.spacing,

      "fontSize": data.fontSize,
      "fontWeight": data.fontWeight.value,

      "cornerRadius": data.cornerRadius,
      "focusedBorderWidth": data.focusedBorderWidth,

      ... _colorsParams,
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
        if (widget.errorBuilder case final errorBuilder?) ValueListenableBuilder(
          valueListenable: controller.message,
          builder: (context, value, _) => errorBuilder(context, value),
        ),
      ],
    );
  }
}


// --> Android <--
class _PinInputFieldAndroid extends StatefulWidget {
  final PinInputAndroid controller;
  final WidgetData data;
  final Widget Function(BuildContext context, String? errorText)? errorBuilder;

  const _PinInputFieldAndroid({
    required this.controller,
    required this.data,
    this.errorBuilder,
  });

  @override
  State<_PinInputFieldAndroid> createState() => _PinInputFieldAndroidState();
}

class _PinInputFieldAndroidState extends State<_PinInputFieldAndroid> with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();
    const duration = Duration(milliseconds: 500);
    animationController = AnimationController(duration: duration, vsync: this)..repeat(reverse: true);
    animation = Tween(begin: 0.0, end: 1.0).animate(animationController);
    Future.delayed(const Duration(milliseconds: 300), (){
      if (mounted) widget.controller.requestFocus();
    });
  }

  @override
  void dispose() {
    animationController.dispose();
    widget.controller._dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final pinPut = widget.controller;

    final inputDecoration = InputDecoration(
      constraints: BoxConstraints.tight(Size(data.size, data.size)),
      contentPadding: EdgeInsets.zero,
      counterText: '',
      filled: true,
      fillColor: data.backgroundColor ?? Colors.white,
      enabledBorder: _defaultBorder.copyWith(
        borderRadius: BorderRadius.circular(data.cornerRadius),
        borderSide: _defaultBorder.borderSide
            .copyWith(color: data.defaultBorderColor),
      ),
      errorBorder: _defaultBorder.copyWith(
        borderRadius: BorderRadius.circular(data.cornerRadius),
        borderSide: _defaultBorder.borderSide
            .copyWith(color: data.defaultBorderColor ?? Colors.redAccent),
      ),
      focusedBorder: _defaultBorder.copyWith(
        borderRadius: BorderRadius.circular(data.cornerRadius),
        borderSide: _defaultBorder.borderSide.copyWith(
          color: data.focusedBorderColor ?? Colors.deepPurple,
          width: data.focusedBorderWidth,
        ),
      ),
    );

    return Column(
      children: [
        SizedBox(
          height: data.size,
          width: double.maxFinite,
          child: TextSelectionTheme(
            data: TextSelectionThemeData(selectionColor: Colors.transparent),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: data.spacing,
              children: (){
                final children = <Widget>[];

                for (int i = 0; i < pinPut._pins.length; i++) {
                  final pin = pinPut._pins[i];

                  final textFormField = TextFormField(
                    cursorColor: Colors.transparent,
                    cursorHeight: 0,
                    key: Key('field_$i'),
                    controller: pin.controller,
                    focusNode: pin.focusNode,

                    decoration: inputDecoration,
                    enableInteractiveSelection: false,
                    inputFormatters: [PinIntFormatter(pinPut._pins, i, pinPut.onEditingComplete)],
                    maxLength: 2,
                    style: TextStyle(color: Colors.transparent),
                    textAlign: TextAlign.center,

                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,

                    onTap: () => pin.modifyOnHold(pin.controller.text.length > 1),
                    onChanged: (value) => pinPut.message.value = null,
                  );

                  final child = ValueListenableBuilder(
                    valueListenable: pin.controller,
                    builder: (_, value, _) => Stack(
                      alignment: Alignment.center,
                      children: [
                        textFormField,
                        IgnorePointer(
                          ignoring: true,
                          child: AnimatedScale(
                            curve: Curves.easeInOut,
                            duration: const Duration(milliseconds: 150),
                            scale: value.text.length > 1 ? 1:0,
                            child: Text(
                              value.text.replaceAll(_placeHolder, ''),
                              style: TextStyle(
                                fontSize: data.fontSize,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          child: ValueListenableBuilder(
                            valueListenable: pin._hasFocus,
                            builder: (_, value, _) {
                              if (value) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: Container(
                                    color: data.cursorColor ?? Colors.blueAccent,
                                    height: 1,
                                    width: data.fontSize,
                                  ),
                                );
                              }

                              return const SizedBox();
                            },
                          ),
                        ),
                      ],
                    ),
                  );

                  children.add(child);
                }

                return children;
              }(),
            ),
          ),
        ),
        if (widget.errorBuilder case final errorBuilder?) ValueListenableBuilder(
          valueListenable: pinPut.message,
          builder: (context, value, _) => errorBuilder(context, value),
        ),
      ],
    );
  }
}