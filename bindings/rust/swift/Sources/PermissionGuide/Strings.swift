import Foundation

/// Built-in UI strings, resolved from the user's preferred languages (English fallback).
/// Embedded in code rather than a resource bundle so static-library and xcframework consumers need nothing extra.
enum Strings {
    enum Key: Int { case dragTitle, dragHint, doneTitle, doneHint, close }

    /// `doneHint` contains a single `%@` for the app name.
    private static let table: [String: [String]] = [
        "en": ["Drag into the list above", "Then turn it on.", "All set", "%@ has access.", "Close"],
        "es": ["Arrastra a la lista de arriba", "Luego actívalo.", "Todo listo", "%@ tiene acceso.", "Cerrar"],
        "fr": ["Faites glisser dans la liste ci-dessus", "Puis activez-la.", "C’est prêt", "%@ a accès.", "Fermer"],
        "de": ["In die Liste oben ziehen", "Dann einschalten.", "Fertig", "%@ hat Zugriff.", "Schließen"],
        "pt": ["Arraste para a lista acima", "Depois ative.", "Tudo pronto", "%@ tem acesso.", "Fechar"],
        "ja": ["上のリストにドラッグ", "その後オンにします。", "完了", "%@ にアクセスが許可されました。", "閉じる"],
        "ko": ["위 목록으로 드래그하세요", "그런 다음 켜세요.", "완료", "%@에 접근 권한이 있습니다.", "닫기"],
        "zh": ["拖到上方列表中", "然后打开开关。", "已完成", "%@ 已获得权限。", "关闭"],
    ]

    static func string(_ key: Key, languages: [String] = Locale.preferredLanguages) -> String {
        let strings = languages.lazy
            .compactMap { Locale(identifier: $0).language.languageCode?.identifier }
            .compactMap { table[$0] }
            .first ?? table["en"]!
        return strings[key.rawValue]
    }
}
