import Foundation

//Okey, esto lo haré en español. Herramienta para modificar la configuración de usuario dentro del firmware de Nintendo DS.
// Basado en especificaciones GBATEK para NDS Firmware User Settings.
public class DSFirmwarePatcher {
    
    public struct UserSettings {
        public var nickname: String
        public var message: String
        public var favoriteColor: Int // 0-15
        public var birthMonth: Int    // 1-12
        public var birthDay: Int      // 1-31
        public var language: Int      // 0-5 (0=JP, 1=EN, 2=FR, 3=DE, 4=IT, 5=ES)
        
        public init(nickname: String, message: String = "Hello!", favoriteColor: Int = 0, birthMonth: Int = 1, birthDay: Int = 1, language: Int = 1) {
            self.nickname = String(nickname.prefix(10)) // Max 10 chars
            self.message = String(message.prefix(26))   // Max 26 chars
            self.favoriteColor = min(max(favoriteColor, 0), 15)
            self.birthMonth = min(max(birthMonth, 1), 12)
            self.birthDay = min(max(birthDay, 1), 31)
            self.language = min(max(language, 0), 5)
        }
    }
    
    // Offsets conocidos en firmware.bin (NVRAM USER SETTINGS)
    private static let SETTINGS_OFFSET_1 = 0x3FE00
    private static let SETTINGS_OFFSET_2 = 0x3FF00
    private static let BLOCK_SIZE = 0x100 // 256 bytes
    
    // Mapa de colores (solo referencia)
    public static let colors: [String] = [
        "Gray", "Brown", "Red", "Pink", "Orange", "Yellow", "Lime", "Green",
        "Dark Green", "Turquoise", "Blue", "Indigo", "Violet", "Purple", "Magenta", "Dark Gray"
    ]
    
    /// Parchea el firmware data con los nuevos ajustes de usuario.
    /// Retorna los nuevos datos del firmware o nil si el firmware no es válido.
    public static func patchFirmware(data: Data, settings: UserSettings) -> Data? {
        var firmware = data
        
        // Validar tamaño mínimo (256KB estándar, algunas dumps pueden ser mayores)
        guard firmware.count >= 0x40000 else {
            print(" [DSFirmwarePatcher] Firmware size too small: \(firmware.count)")
            return nil
        }
        
        // Preparamos el bloque de datos (solo modificamos los bytes necesarios)
        // La estrategia es leer el bloque existente para preservar calibración de pantalla y alarmas,
        // y solo sobrescribir nombre/color/etc.
        
        // Vamos a parchear AMBOS bloques (0x3FE00 y 0x3FF00) para asegurar consistencia.
        // Incrementaremos el Update Counter para asegurar que estos sean los válidos.
        
        if !patchBlock(firmware: &firmware, offset: SETTINGS_OFFSET_1, settings: settings) {
            return nil
        }
        
        if !patchBlock(firmware: &firmware, offset: SETTINGS_OFFSET_2, settings: settings) {
             return nil
        }
        
        print("✅ [DSFirmwarePatcher] Firmware patched successfully!")
        return firmware
    }
    
    private static func patchBlock(firmware: inout Data, offset: Int, settings: UserSettings) -> Bool {
        // Leer bloque existente (70h bytes de datos + contadores + CRC)
        // Datos protegidos por CRC van de 0x00 a 0x6F (112 bytes)
        var block = firmware.subdata(in: offset..<(offset + 0x74))
        
        // Modificar datos (Indices relativos al inicio del bloque)
        
        // 0x02: Favorite Color
        block[0x02] = UInt8(settings.favoriteColor)
        
        // 0x03: Birth Month
        block[0x03] = UInt8(settings.birthMonth)
        
        // 0x04: Birth Day
        block[0x04] = UInt8(settings.birthDay)
        
        // 0x06: Nickname (UTF-16LE, 20 bytes)
        let nameData = settings.nickname.data(using: .utf16LittleEndian)!
        let nameBytes = [UInt8](nameData)
        // Limpiar area con ceros relleno 0x06-0x19 (20 bytes)
        for i in 0..<20 { block[0x06 + i] = 0 }
        // Copiar nombre
        for i in 0..<min(20, nameBytes.count) { block[0x06 + i] = nameBytes[i] }
        
        // 0x1A: Nickname Length (caracteres)
        block[0x1A] = UInt8(settings.nickname.count)
        block[0x1B] = 0 // Padding byte usually 0
        
        // 0x1C: Message (UTF-16LE, 52 bytes)
        let msgData = settings.message.data(using: .utf16LittleEndian)!
        let msgBytes = [UInt8](msgData)
        // Limpiar 0x1C-0x4F (52 bytes)
        for i in 0..<52 { block[0x1C + i] = 0 }
        // Copiar mensaje
        for i in 0..<min(52, msgBytes.count) { block[0x1C + i] = msgBytes[i] }
        
        // 0x50: Message Length
        block[0x50] = UInt8(settings.message.count)
        
        // 0x64: Language and Flags
        // Bit 0-2: Language (0-5)
        // Bit 3: GBA Output (0=LCD, 1=TV)
        let oldVal = block[0x64]
        let langVal = UInt8(settings.language & 0x07)
        block[0x64] = (oldVal & 0xF8) | langVal
        
        // 0x70: Update Counter (UI16) - Leer actual y aumentar uno puede ser seguro, 
        // pero para forzar, vamos a poner un valor alto o simplemente incrementar lo que haya.
        // NDS usa el contador más alto. Si ambos son iguales, usa el 1.
        // Vamos a leer el valor original y sumar 1.
        let currentCounter = firmware.withUnsafeBytes { $0.load(fromByteOffset: offset + 0x70, as: UInt16.self) }
        let newCounter = currentCounter &+ 1 // Overflow allowed
        
        withUnsafeBytes(of: newCounter) {
            block[0x70] = $0[0]
            block[0x71] = $0[1]
        }
        
        // 0x72: CRC16 (Calculado sobre 0x00 a 0x6F)
        let crc = calculateCRC16(data: block.subdata(in: 0..<0x70))
        withUnsafeBytes(of: crc) {
            block[0x72] = $0[0] // CRC se guarda Little Endian en NDS
            block[0x73] = $0[1]
        }
        
        // Escribir bloque modificado de vuelta al firmware
        firmware.replaceSubrange(offset..<(offset + 0x74), with: block)
        return true
    }
    
    // NDS CRC16 Algorithm (CRC-16/MODBUS logic but specific poly/init)
    // Poly: 0xA001 (Reverse of 0x8005), Init: 0xFFFF
    private static func calculateCRC16(data: Data) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        
        for byte in data {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                if (crc & 1) != 0 {
                    crc = (crc >> 1) ^ 0xA001
                } else {
                    crc >>= 1
                }
            }
        }
        
        return crc
    }
}
