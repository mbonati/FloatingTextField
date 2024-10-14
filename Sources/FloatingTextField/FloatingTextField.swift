//
//  FloatingTextField.swift
//
//  Created by Marco Bonati on 12/10/24.
//
import SwiftUI

public struct FloatingTextFieldConfiguration {
    public enum FieldType {
        case plainText
        case secure
    }
    
    public var clearButton: Bool = false
    public var autocapitalization: UITextAutocapitalizationType = .none
    public var autocorrection: Bool = false
    public var textContentType: UITextContentType?
    public var keyboardType: UIKeyboardType = .default
    public var rightIcon: AnyView?
    public var fieldType: FieldType = .plainText
    public var revealSecureContent: Bool = true
    
    public static func configure(_ configuration: (inout FloatingTextFieldConfiguration) -> Void) -> FloatingTextFieldConfiguration {
        var config = FloatingTextFieldConfiguration()
        configuration(&config) // Applica la closure di configurazione
        return config
    }
}

public struct FloatingTextFieldStyle {
    public enum BorderStyle {
        case none
        case rounded(cornerRadius: CGFloat = 16, thickness: CGFloat = 0.8, focusedThickness: CGFloat = 0.8, color: BorderColor = .borderColor())
        case line(thickness: CGFloat = 0.8, focusedThickness: CGFloat = 0.8, color: BorderColor = .borderColor())
        
        fileprivate func alignment() -> Alignment {
            switch self {
            case .none:
                .center
            case .line:
                .bottom
            case .rounded:
                .center
            }
        }
    }
    
    public struct BorderColor {
        var focused: Color = .primary
        var nonFocused: Color = .secondary
        
        public static func borderColor(focused: Color? = .primary, nonFocused: Color? = .secondary) -> BorderColor {
            return BorderColor(focused: focused ?? .primary, nonFocused: nonFocused ?? .secondary)
        }
    }
    
    public var font: Font?
    public var border: BorderStyle = .rounded()
    //public var borderColor: BorderColor = BorderColor()
    
    public static func style(_ style: (inout FloatingTextFieldStyle) -> Void) -> FloatingTextFieldStyle {
        var newStyle = FloatingTextFieldStyle()
        style(&newStyle) // Applica la closure di configurazione
        return newStyle
    }
    

}

public struct FloatingTextField<Content: View>: View {
    @Binding var text: String
    let placeholderText: LocalizedStringKey
    var configuration: FloatingTextFieldConfiguration
    var style: FloatingTextFieldStyle
    var leftContent: (() -> Content)?
    var rightContent: (() -> Content)?

    let animation: Animation = .spring(response: 0.1, dampingFraction: 0.6)
    @State(initialValue: 0) private var placeholderOffset: CGFloat
    @State(initialValue: 1) private var scaleEffectValue: CGFloat
    
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    @State private var isShowingSecureText = false
    
    public init(_ placeholderText: LocalizedStringKey,
                text: Binding<String>,
                configuration: FloatingTextFieldConfiguration? = nil,
                style: FloatingTextFieldStyle? = nil,
                rightContent: (() -> Content)? = nil,
                leftContent: (() -> Content)? = nil)
    {
        self.placeholderText = placeholderText
        self._text = text
        self.configuration = configuration ?? FloatingTextFieldConfiguration()
        self.style = style ?? FloatingTextFieldStyle()
        self.rightContent = rightContent
        self.leftContent = leftContent
        // start with initial offsets
        _placeholderOffset = State(initialValue: $text.wrappedValue.isEmpty ? 0 : -25)
        _scaleEffectValue = State(initialValue: $text.wrappedValue.isEmpty ? 1 : 0.75)
    }
        
    public var body: some View {
        ZStack(alignment: .leading) {
            HStack {
                if let lCont = leftContent {
                    lCont()
                }
                
                ZStack(alignment: .leading) {
                    Text(placeholderText)
                        .foregroundStyle(.secondary)
                        .font($text.wrappedValue.isEmpty ? .headline : .caption)
                        .offset(y: placeholderOffset)
                        .scaleEffect(scaleEffectValue, anchor: .leading)
                    
                    HStack {
                        if configuration.fieldType == .plainText {
                            TextField("", text: $text)
                                .autocapitalization(configuration.autocapitalization)
                                .disableAutocorrection(!configuration.autocorrection)
                                .textContentType(configuration.textContentType)
                                .keyboardType(configuration.keyboardType)
                                .font(style.font)
                                .focused($isTextFieldFocused)
                        } else if configuration.fieldType == .secure {
                            if isShowingSecureText {
                                Text(text)
                                    .opacity(isShowingSecureText ? 1 : 0)
                                    .multilineTextAlignment(.leading)
                                    .font(style.font)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                SecureField("", text: $text)
                                    .opacity(isShowingSecureText ? 0 : 1)
                                    .autocapitalization(configuration.autocapitalization)
                                    .disableAutocorrection(!configuration.autocorrection)
                                    .textContentType(configuration.textContentType)
                                    .font(style.font)
                                    .keyboardType(configuration.keyboardType)
                                    .focused($isTextFieldFocused)
                            }
                        }
                        
                        // REVEAL PASSWORD BUTTON
                        if configuration.revealSecureContent && configuration.fieldType == .secure {
                            revealSecureTextButton()
                        }
                        
                        // CLEAR TEXT BUTTON
                        if !text.isEmpty && self.configuration.clearButton {
                            clearButton()
                        }
                    }
                }
                
                if let rCont = rightContent {
                    rCont()
                }
            }
        }
        .padding(14)
        .padding(.vertical, 4)
        .overlay(
            border(),
            alignment: style.border.alignment()
        )
        .onChange(of: text) { _ in
            withAnimation(animation) {
                calculateOffsets()
            }
        }
    }
    
    private func calculateOffsets() {
        placeholderOffset = $text.wrappedValue.isEmpty ? 0 : -25
        scaleEffectValue = $text.wrappedValue.isEmpty ? 1 : 0.75
    }
    
    @ViewBuilder
    private func clearButton() -> some View {
        Button {
            clearContent()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .tint(isTextFieldFocused ? .primary : .secondary)
        }
    }
    
    @ViewBuilder
    private func revealSecureTextButton() -> some View {
        Button {
            revealSecureText(true)
        } label: {
            Image(systemName: isShowingSecureText ? "eye.slash" : "eye.fill")
                .tint(isTextFieldFocused ? .primary : .secondary)
                .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                    if isPressing {
                    } else {
                        revealSecureText(false)
                    }
                }, perform: {
                    revealSecureText(true)
                })
        }.buttonStyle(PlainButtonStyle()) // Usa PlainButtonStyle per non perdere il focus
    }
    
    @ViewBuilder
    private func border() -> some View {
        switch style.border {
        case .rounded(let cornerRadius, let thickness, let focusedThickness, let color):
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isTextFieldFocused ? color.focused : color.nonFocused,
                        lineWidth: isTextFieldFocused ? focusedThickness : thickness)
        case .line(let thickness, let focusedThickness, let color):
            Rectangle()
                .frame(height: isTextFieldFocused ? focusedThickness : thickness) // Spessore della linea
                .foregroundColor(isTextFieldFocused ? color.focused : color.nonFocused)
        case .none:
            Color.clear
        }
    }
    
    private func clearContent() {
        text = ""
    }
    
    private func revealSecureText(_ reveal: Bool) {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        isShowingSecureText = reveal
    }
}
