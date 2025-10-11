//
//  PhoneNumberFormatter.swift
//  Lopan
//
//  Created by Claude Code on 2025-10-09.
//

import Foundation

/// Utility for formatting phone numbers in native iOS style
/// Formats phone numbers based on country dial codes
struct PhoneNumberFormatter {

    /// Format a phone number for display in native iOS style
    /// - Parameter phoneNumber: Raw phone number (e.g., "+2348012345678")
    /// - Returns: Formatted phone number (e.g., "+234 801 234 5678")
    static func formatForDisplay(_ phoneNumber: String) -> String {
        // Remove all whitespace first
        let cleaned = phoneNumber.trimmingCharacters(in: .whitespaces)

        guard !cleaned.isEmpty else { return phoneNumber }
        guard cleaned.hasPrefix("+") else { return phoneNumber }

        // Extract dial code and number
        let dialCode = extractDialCode(from: cleaned)
        let numberWithoutDialCode = String(cleaned.dropFirst(dialCode.count))

        // Format based on dial code
        let formattedNumber = formatNumber(numberWithoutDialCode, forDialCode: dialCode)

        return "\(dialCode) \(formattedNumber)"
    }

    /// Extract dial code from phone number
    /// - Parameter phoneNumber: Full phone number with dial code
    /// - Returns: Dial code (e.g., "+234", "+1", "+86")
    private static func extractDialCode(from phoneNumber: String) -> String {
        // Try to match known dial codes from longest to shortest
        // This handles cases like +1 (USA/Canada) vs +1-876 (Jamaica)

        // 4-digit dial codes (with hyphens)
        if phoneNumber.hasPrefix("+1-876") { return "+1-876" }  // Jamaica
        if phoneNumber.hasPrefix("+1-809") { return "+1-809" }  // Dominican Republic
        if phoneNumber.hasPrefix("+1-787") { return "+1-787" }  // Puerto Rico
        if phoneNumber.hasPrefix("+1-868") { return "+1-868" }  // Trinidad

        // 3-digit dial codes
        if phoneNumber.hasPrefix("+234") { return "+234" }  // Nigeria
        if phoneNumber.hasPrefix("+880") { return "+880" }  // Bangladesh
        if phoneNumber.hasPrefix("+971") { return "+971" }  // UAE
        if phoneNumber.hasPrefix("+966") { return "+966" }  // Saudi Arabia
        if phoneNumber.hasPrefix("+972") { return "+972" }  // Israel
        if phoneNumber.hasPrefix("+974") { return "+974" }  // Qatar
        if phoneNumber.hasPrefix("+973") { return "+973" }  // Bahrain
        if phoneNumber.hasPrefix("+968") { return "+968" }  // Oman
        if phoneNumber.hasPrefix("+965") { return "+965" }  // Kuwait
        if phoneNumber.hasPrefix("+962") { return "+962" }  // Jordan
        if phoneNumber.hasPrefix("+961") { return "+961" }  // Lebanon
        if phoneNumber.hasPrefix("+970") { return "+970" }  // Palestine
        if phoneNumber.hasPrefix("+963") { return "+963" }  // Syria
        if phoneNumber.hasPrefix("+960") { return "+960" }  // Maldives
        if phoneNumber.hasPrefix("+964") { return "+964" }  // Iraq
        if phoneNumber.hasPrefix("+967") { return "+967" }  // Yemen
        if phoneNumber.hasPrefix("+996") { return "+996" }  // Kyrgyzstan
        if phoneNumber.hasPrefix("+998") { return "+998" }  // Uzbekistan
        if phoneNumber.hasPrefix("+992") { return "+992" }  // Tajikistan
        if phoneNumber.hasPrefix("+993") { return "+993" }  // Turkmenistan
        if phoneNumber.hasPrefix("+995") { return "+995" }  // Georgia
        if phoneNumber.hasPrefix("+994") { return "+994" }  // Azerbaijan
        if phoneNumber.hasPrefix("+976") { return "+976" }  // Mongolia
        if phoneNumber.hasPrefix("+975") { return "+975" }  // Bhutan
        if phoneNumber.hasPrefix("+977") { return "+977" }  // Nepal
        if phoneNumber.hasPrefix("+886") { return "+886" }  // Taiwan
        if phoneNumber.hasPrefix("+852") { return "+852" }  // Hong Kong
        if phoneNumber.hasPrefix("+853") { return "+853" }  // Macau
        if phoneNumber.hasPrefix("+855") { return "+855" }  // Cambodia
        if phoneNumber.hasPrefix("+856") { return "+856" }  // Laos
        if phoneNumber.hasPrefix("+673") { return "+673" }  // Brunei
        if phoneNumber.hasPrefix("+679") { return "+679" }  // Fiji
        if phoneNumber.hasPrefix("+675") { return "+675" }  // Papua New Guinea
        if phoneNumber.hasPrefix("+358") { return "+358" }  // Finland
        if phoneNumber.hasPrefix("+372") { return "+372" }  // Estonia
        if phoneNumber.hasPrefix("+371") { return "+371" }  // Latvia
        if phoneNumber.hasPrefix("+370") { return "+370" }  // Lithuania
        if phoneNumber.hasPrefix("+374") { return "+374" }  // Armenia
        if phoneNumber.hasPrefix("+375") { return "+375" }  // Belarus
        if phoneNumber.hasPrefix("+373") { return "+373" }  // Moldova
        if phoneNumber.hasPrefix("+380") { return "+380" }  // Ukraine
        if phoneNumber.hasPrefix("+382") { return "+382" }  // Montenegro
        if phoneNumber.hasPrefix("+381") { return "+381" }  // Serbia
        if phoneNumber.hasPrefix("+385") { return "+385" }  // Croatia
        if phoneNumber.hasPrefix("+386") { return "+386" }  // Slovenia
        if phoneNumber.hasPrefix("+387") { return "+387" }  // Bosnia
        if phoneNumber.hasPrefix("+389") { return "+389" }  // North Macedonia
        if phoneNumber.hasPrefix("+354") { return "+354" }  // Iceland
        if phoneNumber.hasPrefix("+352") { return "+352" }  // Luxembourg
        if phoneNumber.hasPrefix("+356") { return "+356" }  // Malta
        if phoneNumber.hasPrefix("+357") { return "+357" }  // Cyprus
        if phoneNumber.hasPrefix("+351") { return "+351" }  // Portugal
        if phoneNumber.hasPrefix("+353") { return "+353" }  // Ireland
        if phoneNumber.hasPrefix("+359") { return "+359" }  // Bulgaria
        if phoneNumber.hasPrefix("+420") { return "+420" }  // Czech Republic
        if phoneNumber.hasPrefix("+421") { return "+421" }  // Slovakia
        if phoneNumber.hasPrefix("+355") { return "+355" }  // Albania
        if phoneNumber.hasPrefix("+213") { return "+213" }  // Algeria
        if phoneNumber.hasPrefix("+212") { return "+212" }  // Morocco
        if phoneNumber.hasPrefix("+216") { return "+216" }  // Tunisia
        if phoneNumber.hasPrefix("+218") { return "+218" }  // Libya
        if phoneNumber.hasPrefix("+220") { return "+220" }  // Gambia
        if phoneNumber.hasPrefix("+221") { return "+221" }  // Senegal
        if phoneNumber.hasPrefix("+222") { return "+222" }  // Mauritania
        if phoneNumber.hasPrefix("+223") { return "+223" }  // Mali
        if phoneNumber.hasPrefix("+224") { return "+224" }  // Guinea
        if phoneNumber.hasPrefix("+225") { return "+225" }  // Côte d'Ivoire
        if phoneNumber.hasPrefix("+226") { return "+226" }  // Burkina Faso
        if phoneNumber.hasPrefix("+227") { return "+227" }  // Niger
        if phoneNumber.hasPrefix("+228") { return "+228" }  // Togo
        if phoneNumber.hasPrefix("+229") { return "+229" }  // Benin
        if phoneNumber.hasPrefix("+230") { return "+230" }  // Mauritius
        if phoneNumber.hasPrefix("+231") { return "+231" }  // Liberia
        if phoneNumber.hasPrefix("+232") { return "+232" }  // Sierra Leone
        if phoneNumber.hasPrefix("+233") { return "+233" }  // Ghana
        if phoneNumber.hasPrefix("+235") { return "+235" }  // Chad
        if phoneNumber.hasPrefix("+236") { return "+236" }  // Central African Republic
        if phoneNumber.hasPrefix("+237") { return "+237" }  // Cameroon
        if phoneNumber.hasPrefix("+238") { return "+238" }  // Cape Verde
        if phoneNumber.hasPrefix("+239") { return "+239" }  // São Tomé
        if phoneNumber.hasPrefix("+240") { return "+240" }  // Equatorial Guinea
        if phoneNumber.hasPrefix("+241") { return "+241" }  // Gabon
        if phoneNumber.hasPrefix("+242") { return "+242" }  // Republic of Congo
        if phoneNumber.hasPrefix("+243") { return "+243" }  // DR Congo
        if phoneNumber.hasPrefix("+244") { return "+244" }  // Angola
        if phoneNumber.hasPrefix("+245") { return "+245" }  // Guinea-Bissau
        if phoneNumber.hasPrefix("+246") { return "+246" }  // Diego Garcia
        if phoneNumber.hasPrefix("+248") { return "+248" }  // Seychelles
        if phoneNumber.hasPrefix("+249") { return "+249" }  // Sudan
        if phoneNumber.hasPrefix("+250") { return "+250" }  // Rwanda
        if phoneNumber.hasPrefix("+251") { return "+251" }  // Ethiopia
        if phoneNumber.hasPrefix("+252") { return "+252" }  // Somalia
        if phoneNumber.hasPrefix("+253") { return "+253" }  // Djibouti
        if phoneNumber.hasPrefix("+254") { return "+254" }  // Kenya
        if phoneNumber.hasPrefix("+255") { return "+255" }  // Tanzania
        if phoneNumber.hasPrefix("+256") { return "+256" }  // Uganda
        if phoneNumber.hasPrefix("+257") { return "+257" }  // Burundi
        if phoneNumber.hasPrefix("+258") { return "+258" }  // Mozambique
        if phoneNumber.hasPrefix("+260") { return "+260" }  // Zambia
        if phoneNumber.hasPrefix("+261") { return "+261" }  // Madagascar
        if phoneNumber.hasPrefix("+262") { return "+262" }  // Réunion
        if phoneNumber.hasPrefix("+263") { return "+263" }  // Zimbabwe
        if phoneNumber.hasPrefix("+264") { return "+264" }  // Namibia
        if phoneNumber.hasPrefix("+265") { return "+265" }  // Malawi
        if phoneNumber.hasPrefix("+266") { return "+266" }  // Lesotho
        if phoneNumber.hasPrefix("+267") { return "+267" }  // Botswana
        if phoneNumber.hasPrefix("+268") { return "+268" }  // Eswatini
        if phoneNumber.hasPrefix("+269") { return "+269" }  // Comoros
        if phoneNumber.hasPrefix("+590") { return "+590" }  // Guadeloupe
        if phoneNumber.hasPrefix("+591") { return "+591" }  // Bolivia
        if phoneNumber.hasPrefix("+592") { return "+592" }  // Guyana
        if phoneNumber.hasPrefix("+593") { return "+593" }  // Ecuador
        if phoneNumber.hasPrefix("+594") { return "+594" }  // French Guiana
        if phoneNumber.hasPrefix("+595") { return "+595" }  // Paraguay
        if phoneNumber.hasPrefix("+596") { return "+596" }  // Martinique
        if phoneNumber.hasPrefix("+597") { return "+597" }  // Suriname
        if phoneNumber.hasPrefix("+598") { return "+598" }  // Uruguay
        if phoneNumber.hasPrefix("+506") { return "+506" }  // Costa Rica
        if phoneNumber.hasPrefix("+507") { return "+507" }  // Panama
        if phoneNumber.hasPrefix("+505") { return "+505" }  // Nicaragua
        if phoneNumber.hasPrefix("+504") { return "+504" }  // Honduras
        if phoneNumber.hasPrefix("+503") { return "+503" }  // El Salvador
        if phoneNumber.hasPrefix("+502") { return "+502" }  // Guatemala

        // 2-digit dial codes
        if phoneNumber.hasPrefix("+1") { return "+1" }   // USA/Canada
        if phoneNumber.hasPrefix("+7") { return "+7" }   // Russia/Kazakhstan
        if phoneNumber.hasPrefix("+20") { return "+20" }  // Egypt
        if phoneNumber.hasPrefix("+27") { return "+27" }  // South Africa
        if phoneNumber.hasPrefix("+30") { return "+30" }  // Greece
        if phoneNumber.hasPrefix("+31") { return "+31" }  // Netherlands
        if phoneNumber.hasPrefix("+32") { return "+32" }  // Belgium
        if phoneNumber.hasPrefix("+33") { return "+33" }  // France
        if phoneNumber.hasPrefix("+34") { return "+34" }  // Spain
        if phoneNumber.hasPrefix("+36") { return "+36" }  // Hungary
        if phoneNumber.hasPrefix("+39") { return "+39" }  // Italy
        if phoneNumber.hasPrefix("+40") { return "+40" }  // Romania
        if phoneNumber.hasPrefix("+41") { return "+41" }  // Switzerland
        if phoneNumber.hasPrefix("+43") { return "+43" }  // Austria
        if phoneNumber.hasPrefix("+44") { return "+44" }  // UK
        if phoneNumber.hasPrefix("+45") { return "+45" }  // Denmark
        if phoneNumber.hasPrefix("+46") { return "+46" }  // Sweden
        if phoneNumber.hasPrefix("+47") { return "+47" }  // Norway
        if phoneNumber.hasPrefix("+48") { return "+48" }  // Poland
        if phoneNumber.hasPrefix("+49") { return "+49" }  // Germany
        if phoneNumber.hasPrefix("+51") { return "+51" }  // Peru
        if phoneNumber.hasPrefix("+52") { return "+52" }  // Mexico
        if phoneNumber.hasPrefix("+53") { return "+53" }  // Cuba
        if phoneNumber.hasPrefix("+54") { return "+54" }  // Argentina
        if phoneNumber.hasPrefix("+55") { return "+55" }  // Brazil
        if phoneNumber.hasPrefix("+56") { return "+56" }  // Chile
        if phoneNumber.hasPrefix("+57") { return "+57" }  // Colombia
        if phoneNumber.hasPrefix("+58") { return "+58" }  // Venezuela
        if phoneNumber.hasPrefix("+60") { return "+60" }  // Malaysia
        if phoneNumber.hasPrefix("+61") { return "+61" }  // Australia
        if phoneNumber.hasPrefix("+62") { return "+62" }  // Indonesia
        if phoneNumber.hasPrefix("+63") { return "+63" }  // Philippines
        if phoneNumber.hasPrefix("+64") { return "+64" }  // New Zealand
        if phoneNumber.hasPrefix("+65") { return "+65" }  // Singapore
        if phoneNumber.hasPrefix("+66") { return "+66" }  // Thailand
        if phoneNumber.hasPrefix("+81") { return "+81" }  // Japan
        if phoneNumber.hasPrefix("+82") { return "+82" }  // South Korea
        if phoneNumber.hasPrefix("+84") { return "+84" }  // Vietnam
        if phoneNumber.hasPrefix("+86") { return "+86" }  // China
        if phoneNumber.hasPrefix("+90") { return "+90" }  // Turkey
        if phoneNumber.hasPrefix("+91") { return "+91" }  // India
        if phoneNumber.hasPrefix("+92") { return "+92" }  // Pakistan
        if phoneNumber.hasPrefix("+93") { return "+93" }  // Afghanistan
        if phoneNumber.hasPrefix("+94") { return "+94" }  // Sri Lanka
        if phoneNumber.hasPrefix("+95") { return "+95" }  // Myanmar
        if phoneNumber.hasPrefix("+98") { return "+98" }  // Iran

        // Fallback: try to extract first 2-4 characters as dial code
        if phoneNumber.count >= 4 {
            return String(phoneNumber.prefix(4))
        } else if phoneNumber.count >= 3 {
            return String(phoneNumber.prefix(3))
        } else if phoneNumber.count >= 2 {
            return String(phoneNumber.prefix(2))
        }

        return phoneNumber
    }

    /// Format number without dial code based on country formatting conventions
    /// - Parameters:
    ///   - number: Phone number without dial code
    ///   - dialCode: Country dial code
    /// - Returns: Formatted number
    private static func formatNumber(_ number: String, forDialCode dialCode: String) -> String {
        guard !number.isEmpty else { return number }

        // Remove any existing spaces or formatting
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        switch dialCode {
        // Nigeria: +234 801 234 5678 (3-3-4)
        case "+234":
            return formatPattern(cleaned, pattern: [3, 3, 4])

        // USA/Canada: +1 (650) 555-1234 (3-3-4 with parentheses)
        case "+1", "+1-876", "+1-809", "+1-787", "+1-868":
            if cleaned.count >= 10 {
                let areaCode = String(cleaned.prefix(3))
                let prefix = String(cleaned.dropFirst(3).prefix(3))
                let line = String(cleaned.dropFirst(6))
                return "(\(areaCode)) \(prefix)-\(line)"
            }
            return formatPattern(cleaned, pattern: [3, 3, 4])

        // China: +86 138 1234 5678 (3-4-4)
        case "+86":
            return formatPattern(cleaned, pattern: [3, 4, 4])

        // UK: +44 20 1234 5678 (2-4-4)
        case "+44":
            if cleaned.count >= 10 {
                return formatPattern(cleaned, pattern: [2, 4, 4])
            }
            return formatPattern(cleaned, pattern: [3, 3, 4])

        // Germany: +49 30 12345678 (2-8)
        case "+49":
            if cleaned.count >= 10 {
                return formatPattern(cleaned, pattern: [2, 4, 4])
            }
            return formatPattern(cleaned, pattern: [3, 3, 4])

        // France: +33 1 23 45 67 89 (1-2-2-2-2)
        case "+33":
            return formatPattern(cleaned, pattern: [1, 2, 2, 2, 2])

        // India: +91 98765 43210 (5-5)
        case "+91":
            return formatPattern(cleaned, pattern: [5, 5])

        // Japan: +81 3-1234-5678 (1-4-4 with hyphens)
        case "+81":
            if cleaned.count >= 9 {
                let area = String(cleaned.prefix(1))
                let prefix = String(cleaned.dropFirst(1).prefix(4))
                let line = String(cleaned.dropFirst(5))
                return "\(area)-\(prefix)-\(line)"
            }
            return formatPattern(cleaned, pattern: [3, 4, 4])

        // Australia: +61 2 1234 5678 (1-4-4)
        case "+61":
            return formatPattern(cleaned, pattern: [1, 4, 4])

        // Brazil: +55 11 91234-5678 (2-5-4)
        case "+55":
            return formatPattern(cleaned, pattern: [2, 5, 4])

        // Russia: +7 495 123 45 67 (3-3-2-2)
        case "+7":
            return formatPattern(cleaned, pattern: [3, 3, 2, 2])

        // South Africa: +27 21 123 4567 (2-3-4)
        case "+27":
            return formatPattern(cleaned, pattern: [2, 3, 4])

        // Default formatting: Group by 3 or 4 digits
        default:
            if cleaned.count >= 10 {
                return formatPattern(cleaned, pattern: [3, 3, 4])
            } else if cleaned.count >= 7 {
                return formatPattern(cleaned, pattern: [3, 4])
            } else {
                return formatPattern(cleaned, pattern: [3, 3])
            }
        }
    }

    /// Format a number according to a pattern
    /// - Parameters:
    ///   - number: Cleaned number string
    ///   - pattern: Array of digit group sizes (e.g., [3, 3, 4] for "xxx xxx xxxx")
    /// - Returns: Formatted number
    private static func formatPattern(_ number: String, pattern: [Int]) -> String {
        var result = ""
        var remaining = number

        for groupSize in pattern {
            guard !remaining.isEmpty else { break }

            let groupEnd = min(groupSize, remaining.count)
            let group = String(remaining.prefix(groupEnd))
            result += (result.isEmpty ? "" : " ") + group
            remaining = String(remaining.dropFirst(groupEnd))
        }

        // Add any remaining digits
        if !remaining.isEmpty {
            result += " " + remaining
        }

        return result
    }

    /// Format phone number for accessibility (spoken aloud by VoiceOver)
    /// - Parameter phoneNumber: Raw phone number
    /// - Returns: Phone number formatted for accessibility
    static func formatForAccessibility(_ phoneNumber: String) -> String {
        // For accessibility, use formatted display but spell out groupings
        // iOS VoiceOver will naturally pause at spaces
        return formatForDisplay(phoneNumber)
    }

    /// Strip all formatting from a phone number (for storage/comparison)
    /// - Parameter phoneNumber: Formatted or unformatted phone number
    /// - Returns: Clean phone number (e.g., "+2348012345678")
    static func stripFormatting(_ phoneNumber: String) -> String {
        // Keep only + and digits
        let allowed = CharacterSet(charactersIn: "+0123456789")
        return phoneNumber.components(separatedBy: allowed.inverted).joined()
    }
}
