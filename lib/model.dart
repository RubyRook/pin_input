part of 'pin_input_method_channel.dart';

final class PinIntFormatter extends TextInputFormatter {
  final List<Pin> pins;
  final int index;
  final void Function()? onEditingComplete;
  PinIntFormatter(this.pins, this.index, this.onEditingComplete);

  @override
  TextEditingValue formatEditUpdate(oldValue, newValue) {
    final length = pins.length;
    final pin = pins[index];
    final text = newValue.text.replaceAll(_placeHolder, '');

    if (text.isEmpty) {
      if (pin._onHold) {
        pin.modifyOnHold(false);
      }
      else if (index > 0) {
        FocusManager.instance.primaryFocus?.previousFocus();

        final i = index - 1;
        if (i == 0 && pins[i].controller.text.length > 1) {
          pins[i].modifyOnHold(true);
        }
      }
      else if (index == 0) {
        FocusManager.instance.primaryFocus?.unfocus();
      }

      return TextEditingValue(
        text: _placeHolder,
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: 1,
        ),
      );
    }
    else {
      final isValid = validate(text);

      if (isValid) {
        if (index < length - 1) {
          if (pins.asMap()[index+1] case final next? when next.controller.text.length > 1) {
            next.modifyOnHold(true);
          }

          FocusManager.instance.primaryFocus?.nextFocus();
        }
        else {
          FocusManager.instance.primaryFocus?.unfocus();
          Future.delayed(const Duration(milliseconds: 333), onEditingComplete);
        }

        return TextEditingValue(
          text: '$_placeHolder$text',
          selection: TextSelection(
            baseOffset: 0,
            extentOffset: '$_placeHolder$text'.length,
          ),
        );
      }
      else {
        return TextEditingValue(
          text: oldValue.text,
          selection: TextSelection(
            baseOffset: 0,
            extentOffset: oldValue.text.length,
          ),
        );
      }
    }
  }

  bool validate(String value) {
    final spaceRegex = RegExp(r'\s');
    if (spaceRegex.hasMatch(value)) {
      return false;
    }

    if (value.isNotEmpty) {
      final regex = RegExp(r'^[0-9]+$');
      return regex.hasMatch(value);
    }

    return true;
  }
}

final class Pin {
  Pin() {
    focusNode.addListener(() {
      _hasFocus.value = focusNode.hasFocus;

      if (focusNode.hasFocus) {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      }
      else {
        _onHold = false;
      }
    },);
  }

  final controller = TextEditingController(text: _placeHolder);
  final focusNode = FocusNode();
  final _hasFocus = ValueNotifier<bool>(false);

  bool _onHold = false;

  void modifyOnHold(bool value)=> _onHold = value;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
    _hasFocus.dispose();
  }
}