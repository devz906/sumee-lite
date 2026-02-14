import WebKit

/// Subclase de WKWebView que permite recibir eventos de controles de videojuegos
/// Esta clase sobrescribe `canBecomeFirstResponder` para que iOS le permita
/// capturar eventos del Gamepad API en HTML5
class GamepadWebView: WKWebView {
    /// Permite que esta vista se convierta en el First Responder
    /// Esto es necesario para que la API de Gamepad funcione en WKWebView
    override var canBecomeFirstResponder: Bool {
        return true
    }
}
