import Flutter
import UIKit

let channelName: String = "pin_input_field"
let weight: [Int:UIFont.Weight] =
  [300: .light, 400: .regular, 500: .medium, 600: .semibold, 700: .bold]

protocol CustomTextFieldDelegate: AnyObject {
  func clearTag()

  func textFieldDidPressBackspace(_ textField: CustomTextField)

  func textField(
    _ textField: CustomTextField,
    shouldChangeCharactersIn range: NSRange,
    replacementString string: String) -> Bool
}

class CustomTextField: UITextField, UITextFieldDelegate {
  weak var customTextFieldDelegate: CustomTextFieldDelegate?

  @IBInspectable var cornerRadius: Double = 5.0
  @IBInspectable var defaultBorderColor: UIColor = .lightGray
  @IBInspectable var focusedBorderColor: UIColor = .blue
  @IBInspectable var focusedBorderWidth: Double = 1.0
  @IBInspectable var fontColor: UIColor = .black
  @IBInspectable var invalidColor: UIColor = .red

  let cursorView = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  // Hides the selection rectangles. [1]
  override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
    return []
  }

  // Prevents the editing menu (cut, copy) from appearing.
  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(UIResponderStandardEditActions.paste(_:)) {
      return true // Allow paste
    }
    return false
  }

  override func deleteBackward() {
    let text:  String = self.text ?? ""
    var cursorPosition: Int = 0

    if let selectedRange = self.selectedTextRange {
      cursorPosition = self.offset(from: self.beginningOfDocument, to: selectedRange.start)
    }

    super.deleteBackward()

    if cursorPosition == 0 && !text.isEmpty {
      self.text = ""
    }
    else if text.isEmpty {
      customTextFieldDelegate?.textFieldDidPressBackspace(self)
    }
    else {
      self.becomeFirstResponder()
    }
  }

  private func setupView() {
    self.clipsToBounds = true
    delegate = self
    borderStyle = .roundedRect
    layer.borderColor = defaultBorderColor.cgColor
    layer.borderWidth = 1.0
    layer.cornerRadius = cornerRadius

    // Configure the custom cursor view
    cursorView.backgroundColor = defaultBorderColor
    cursorView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(cursorView)

    var activate = [
      cursorView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 12),
      cursorView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -12),
      cursorView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8),
      cursorView.heightAnchor.constraint(equalToConstant: 1) // Set the cursor thickness
    ]
    NSLayoutConstraint.activate(activate)
    cursorView.isHidden = true
  }

  override func becomeFirstResponder() -> Bool {
    let result = super.becomeFirstResponder()
    if result {
      layer.borderColor = focusedBorderColor.cgColor
      layer.borderWidth = focusedBorderWidth
      cursorView.isHidden = false
      startCursorAnimation()
    }
    return result
  }

  override func resignFirstResponder() -> Bool {
    customTextFieldDelegate?.clearTag()

    let result = super.resignFirstResponder()
    if result {
      layer.borderColor = defaultBorderColor.cgColor
      layer.borderWidth = 1.0
      cursorView.isHidden = true // Hide the cursor
      cursorView.layer.removeAllAnimations()
    }
    return result
  }

  func startCursorAnimation() {
    // Ensure the cursor is visible before starting the animation
    self.cursorView.alpha = 1.0

    // Create a repeating animation
    UIView.animate(withDuration: 0.5, // The duration of one fade (in or out)
                   delay: 0,
                   options: [.autoreverse, .repeat, .allowUserInteraction],
                   animations: {
                     self.cursorView.alpha = 0.0
                   },
                   completion: nil)
  }

  func textField(
    _ textField: UITextField,
    shouldChangeCharactersIn range: NSRange,
    replacementString string: String
  ) -> Bool {
    return customTextFieldDelegate?.textField(
      self,
      shouldChangeCharactersIn: range,
      replacementString: string) ?? true
  }
}

// ---------->

class PinInputView: NSObject, FlutterPlatformView, CustomTextFieldDelegate {
  private var args: [String: Any] = [:]
  private let frame: CGRect
  private let viewId: Int64
  private let uiView: UIView
  private let methodChannel: FlutterMethodChannel

  private var pinTextFields: [CustomTextField] = []
  private var pinLength: Int = 4
  private var enteredPin: String = "" {
    didSet {
      // Update UI or trigger action when PIN is complete
      if enteredPin.count == pinLength {
        print("PIN entered: \(enteredPin)")
        methodChannel.invokeMethod("pinResult", arguments: enteredPin)
      }
    }
  }

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.frame = frame
    self.viewId = viewId
    self.uiView = UIView(frame: frame)
    self.methodChannel = FlutterMethodChannel(name: "\(channelName)_\(viewId)", binaryMessenger: messenger)

    if let arguments = args as? [String: Any] {
      self.args = arguments
      if let lengthFromFlutter = arguments["pinLength"] as? Int {
        self.pinLength = lengthFromFlutter
      }
    }

    super.init()

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    self.uiView.addGestureRecognizer(tapGesture)

    self.setupPinInputFields()
    self.setupMethodChannel()
  }

  func setupPinInputFields() {
    // --> Define arguments <--
    let heightAnchor = self.args["size"] as? Double ?? 50.0
    let spacing = self.args["spacing"] as? Double ?? 10.0
    let widthAnchor = Double(pinLength) * heightAnchor + (Double(pinLength) - 1) * spacing

    let backgroundColor = self.getColor(self.args["backgroundColor"], defaultColor: .white)
    let cornerRadius = self.args["cornerRadius"] as? Double ?? 5.0
    let cursorColor = self.getColor(self.args["cursorColor"], defaultColor: .lightGray)
    let defaultBorderColor = self.getColor(self.args["defaultBorderColor"], defaultColor: .lightGray)
    let focusedBorderColor = self.getColor(self.args["focusedBorderColor"], defaultColor: .lightGray)
    let focusedBorderWidth = self.args["focusedBorderWidth"] as? Double ?? 2.0
    let invalidColor = self.getColor(self.args["invalidColor"], defaultColor: .red)

    let fontColor = self.getColor(self.args["fontColor"], defaultColor: .black)
    let fontSize = self.args["fontSize"] as? Double ?? 16.0
    let fontWeight = self.args["fontWeight"] as? Int ?? 500

    // --> Setup View <--
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .fillEqually
    stackView.spacing = spacing
    stackView.translatesAutoresizingMaskIntoConstraints = false
    self.uiView.addSubview(stackView)

    var activate = [
      stackView.centerXAnchor.constraint(equalTo: self.uiView.centerXAnchor),
      stackView.heightAnchor.constraint(equalToConstant: heightAnchor),
      // Adjust width based on pinLength and spacing
      stackView.widthAnchor.constraint(equalToConstant: widthAnchor)
    ]
    NSLayoutConstraint.activate(activate)

    for i in 0..<pinLength {
      let textField = CustomTextField()
      textField.backgroundColor = backgroundColor
      textField.cursorView.backgroundColor = cursorColor
      textField.font = .systemFont(ofSize: fontSize, weight: weight[fontWeight] ?? .regular)
      textField.fontColor = fontColor
      textField.textColor = fontColor

      textField.cornerRadius = cornerRadius
      textField.defaultBorderColor = defaultBorderColor
      textField.focusedBorderColor = focusedBorderColor
      textField.focusedBorderWidth = focusedBorderWidth
      textField.invalidColor = invalidColor

      textField.layer.borderColor = defaultBorderColor.cgColor
      textField.layer.cornerRadius = cornerRadius

      textField.customTextFieldDelegate = self
      textField.textAlignment = .center
      textField.tintColor = .clear
      textField.keyboardType = .numberPad
      // textField.textContentType = .oneTimeCode
      textField.borderStyle = .roundedRect
      textField.tag = i // Use tag to identify text fields
      textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)

      if i == 0 {
        textField.textContentType = .oneTimeCode
      }

      pinTextFields.append(textField)
      stackView.addArrangedSubview(textField)
    }

    pinTextFields.first?.becomeFirstResponder()
  }

  func setupMethodChannel() {
    self.methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
        case "changePinLength":
          if let args = call.arguments as? [String: Any], let newLength = args["pinLength"] as? Int {
            self!.args["pinLength"] = newLength;
            self?.updatePinLength(to: newLength)
            result(nil)
          } else {
            self?.invalidArgument("pinLength not provided or not an Int", result)
          }

        case "onError":
          if let args = call.arguments as? [String: Any], let message = args["message"] as? String {
            self?.onErrorState(message: message)
            result(nil)
          } else {
            self?.invalidArgument("Error message not provided or not a String", result)
          }

        case "clearErrorState":
          self?.clearErrorState()

        case "unfocus":
          self?.dismissKeyboard()

        case "pinResult":
          result(self?.enteredPin)

        default:
          result(FlutterMethodNotImplemented)
        }
    }
  }

  private func invalidArgument(_ message: String, _ result: @escaping FlutterResult) {
    result(FlutterError(
      code: "INVALID_ARGUMENT",
      message: message,
      details: nil
    ))
  }

  private func onErrorState(message: String) {
    // Update border color for all text fields
    for textField in pinTextFields {
      textField.layer.borderColor = UIColor.red.cgColor
      textField.textColor = textField.invalidColor
    }
  }

  private func clearErrorState() {
    // Restore the default border color for all non-focused fields
    for (index, textField) in pinTextFields.enumerated() {
      // Only change the border if the text field is not the one currently being edited
      if !textField.isFirstResponder {
        textField.layer.borderColor = textField.defaultBorderColor.cgColor
        textField.textColor = textField.fontColor
      }
    }
  }

  @objc private func textFieldDidChange(_ textField: CustomTextField) {
    clearErrorState()
    let currentText = textField.text ?? ""

    if currentText.count == 1 {
      // Move focus to the next text field
      if textField.tag < pinLength - 1 {
        pinTextFields[textField.tag + 1].becomeFirstResponder()
      } else {
        // Last text field, dismiss keyboard
        textField.resignFirstResponder()
      }
    } else if currentText.isEmpty {
      // Handle backspace: move focus to previous text field
      if textField.tag > 0 {
        pinTextFields[textField.tag - 1].becomeFirstResponder()
      }
    }

    // Reconstruct the entered PIN
    enteredPin = pinTextFields.reduce("") { (result, field) in
      result + (field.text ?? "")
    }
  }

  @objc func dismissKeyboard() {
    // Dismiss the keyboard for the entire view hierarchy
    self.uiView.endEditing(true)
  }

  func getColor(_ param: Any?, defaultColor: UIColor)-> UIColor {
    if let hex = param as? String, let result = UIColor(hex: hex)  {
      return result
    }

    return defaultColor
  }

  func textFieldDidPressBackspace(_ textField: CustomTextField) {
    // print("Backspace pressed in the custom text field! : \(textField.text)")

    if textField.text == nil || textField.text!.isEmpty {
      if textField.tag > 0 {
        pinTextFields[textField.tag - 1].becomeFirstResponder()
      }
      else {
        textField.resignFirstResponder()
      }
    }
  }

  func updatePinLength(to newLength: Int) {
    // Prevent unnecessary redraws if the length is the same
    guard newLength != self.pinLength && newLength > 0 else { return }

    print("Dynamically changing pin length to: \(newLength)")
    self.pinLength = newLength

    // 2. Remove the existing UI elements
    // Find the stack view and remove it from the superview
    if let stackView = self.uiView.subviews.first(where: { $0 is UIStackView }) {
      stackView.removeFromSuperview()
    }

    // Clear the old text field references
    self.pinTextFields.removeAll()
    self.enteredPin = ""

    // 3. Rebuild the UI with the new length
    self.setupPinInputFields()
  }

  var tag: Int? = nil
  func textField(
    _ textField: CustomTextField,
    shouldChangeCharactersIn range: NSRange,
    replacementString string: String
  ) -> Bool {
    print("replacementString: \(string)")
    print("textField.tag: \(textField.tag)")

    // - This condition part is based on this method that provide two time empty replacementString with the same tag
    if textField.tag > 0 && string.isEmpty && (textField.text == nil || textField.text!.isEmpty) {
      if tag == nil {
        tag = textField.tag
      }
      // Same tag as previous field, it's likely an OTP autofill. It common behavior when loop OTP code.
      else if tag == textField.tag {
        tag = nil
        pinTextFields.first?.becomeFirstResponder()
        return false
      }
    }

    // If the incoming string is longer than one character, it's likely copy and past.
    if string.count > 1 {
      for (index, character) in string.enumerated() {
        if index < pinTextFields.count {
          pinTextFields[index].text = String(character)
        }
      }

      // Move focus to the last field and update the entered PIN.
      pinTextFields.last?.becomeFirstResponder()
      textFieldDidChange(pinTextFields.last!) // Trigger an update

      // Prevent the original text field from being updated with the full string.
      return false
    }

    // This handles single-character input and backspacing.
    if string.count == 1 && (textField.text?.count ?? 0) > 0 {
      textField.text = string
      textFieldDidChange(textField)
      return false // Manually set the text, so prevent default behavior.
    }

    let currentText = textField.text ?? ""
    guard let stringRange = Range(range, in: currentText) else { return false }
    let updatedText = currentText.replacingCharacters(in: stringRange, with: string)

    // Allow only single-digit input or clearing the field.
    return updatedText.count <= 1
  }

  func clearTag() {
    print("clearTag: \(tag)")
    tag = nil
  }

  func view() -> UIView {
    return uiView
  }
}

class PinInputViewFactory: NSObject, FlutterPlatformViewFactory {
  private var messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  // This is the required method to create a platform view
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return PinInputView(frame: frame, viewId: viewId, args: args, messenger: self.messenger)
  }

  // Optional: Implement if you need to pass arguments to the factory
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

// ---------->

public class PinInputPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let factory = PinInputViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: channelName)

    // The method channel for platform-level communication.
    let channel = FlutterMethodChannel(name: "pin_input", binaryMessenger: registrar.messenger())
    let instance = PinInputPlugin()

    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

extension UIColor {
  public convenience init?(hex: String) {
    let r, g, b: CGFloat

    if hex.hasPrefix("#") {
      let start = hex.index(hex.startIndex, offsetBy: 1)
      let hexColor = String(hex[start...])

      if hexColor.count == 6 {
        let scanner = Scanner(string: hexColor)
        var hexNumber: UInt64 = 0

        if scanner.scanHexInt64(&hexNumber) {
          r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
          g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
          b = CGFloat(hexNumber & 0x0000ff) / 255

          self.init(red: r, green: g, blue: b, alpha: 1.0)
          return
        }
      }
    }
    return nil
  }
}