import Foundation

struct City: Identifiable, Hashable {
    let code: String
    let name: String
    let zone: String
    let latitude: Double
    let longitude: Double
    var id: String { code }

    var timeZone: TimeZone { TimeZone(identifier: zone) ?? .gmt }

    static func find(_ code: String) -> City? { all.first { $0.code == code } }

    static let all: [City] = [
        City(code: "AMS", name: "AMSTERDAM", zone: "Europe/Amsterdam", latitude: 52.3, longitude: 4.8),
        City(code: "ATH", name: "ATHENS", zone: "Europe/Athens", latitude: 37.9, longitude: 23.9),
        City(code: "AKL", name: "AUCKLAND", zone: "Pacific/Auckland", latitude: -37.0, longitude: 174.8),
        City(code: "BKK", name: "BANGKOK", zone: "Asia/Bangkok", latitude: 13.7, longitude: 100.7),
        City(code: "BCN", name: "BARCELONA", zone: "Europe/Madrid", latitude: 41.3, longitude: 2.1),
        City(code: "PEK", name: "BEIJING", zone: "Asia/Shanghai", latitude: 40.1, longitude: 116.6),
        City(code: "BER", name: "BERLIN", zone: "Europe/Berlin", latitude: 52.4, longitude: 13.5),
        City(code: "BOG", name: "BOGOTA", zone: "America/Bogota", latitude: 4.7, longitude: -74.1),
        City(code: "EZE", name: "BUENOS AIRES", zone: "America/Argentina/Buenos_Aires", latitude: -34.8, longitude: -58.5),
        City(code: "CAI", name: "CAIRO", zone: "Africa/Cairo", latitude: 30.1, longitude: 31.4),
        City(code: "CPT", name: "CAPE TOWN", zone: "Africa/Johannesburg", latitude: -34.0, longitude: 18.6),
        City(code: "ORD", name: "CHICAGO", zone: "America/Chicago", latitude: 42.0, longitude: -87.9),
        City(code: "CPH", name: "COPENHAGEN", zone: "Europe/Copenhagen", latitude: 55.6, longitude: 12.6),
        City(code: "DEL", name: "DELHI", zone: "Asia/Kolkata", latitude: 28.6, longitude: 77.1),
        City(code: "DEN", name: "DENVER", zone: "America/Denver", latitude: 39.9, longitude: -104.7),
        City(code: "DOH", name: "DOHA", zone: "Asia/Qatar", latitude: 25.3, longitude: 51.6),
        City(code: "DXB", name: "DUBAI", zone: "Asia/Dubai", latitude: 25.3, longitude: 55.4),
        City(code: "DUB", name: "DUBLIN", zone: "Europe/Dublin", latitude: 53.4, longitude: -6.3),
        City(code: "FRA", name: "FRANKFURT", zone: "Europe/Berlin", latitude: 50.0, longitude: 8.6),
        City(code: "HEL", name: "HELSINKI", zone: "Europe/Helsinki", latitude: 60.3, longitude: 25.0),
        City(code: "HKG", name: "HONG KONG", zone: "Asia/Hong_Kong", latitude: 22.3, longitude: 113.9),
        City(code: "HNL", name: "HONOLULU", zone: "Pacific/Honolulu", latitude: 21.3, longitude: -157.9),
        City(code: "IST", name: "ISTANBUL", zone: "Europe/Istanbul", latitude: 41.3, longitude: 28.7),
        City(code: "CGK", name: "JAKARTA", zone: "Asia/Jakarta", latitude: -6.1, longitude: 106.7),
        City(code: "JNB", name: "JOHANNESBURG", zone: "Africa/Johannesburg", latitude: -26.1, longitude: 28.2),
        City(code: "KUL", name: "KUALA LUMPUR", zone: "Asia/Kuala_Lumpur", latitude: 2.7, longitude: 101.7),
        City(code: "LOS", name: "LAGOS", zone: "Africa/Lagos", latitude: 6.6, longitude: 3.3),
        City(code: "LIM", name: "LIMA", zone: "America/Lima", latitude: -12.0, longitude: -77.1),
        City(code: "LIS", name: "LISBON", zone: "Europe/Lisbon", latitude: 38.8, longitude: -9.1),
        City(code: "LHR", name: "LONDON", zone: "Europe/London", latitude: 51.5, longitude: -0.5),
        City(code: "LAX", name: "LOS ANGELES", zone: "America/Los_Angeles", latitude: 33.9, longitude: -118.4),
        City(code: "MAD", name: "MADRID", zone: "Europe/Madrid", latitude: 40.5, longitude: -3.6),
        City(code: "MNL", name: "MANILA", zone: "Asia/Manila", latitude: 14.5, longitude: 121.0),
        City(code: "MEL", name: "MELBOURNE", zone: "Australia/Melbourne", latitude: -37.7, longitude: 144.8),
        City(code: "MEX", name: "MEXICO CITY", zone: "America/Mexico_City", latitude: 19.4, longitude: -99.1),
        City(code: "MIA", name: "MIAMI", zone: "America/New_York", latitude: 25.8, longitude: -80.3),
        City(code: "BOM", name: "MUMBAI", zone: "Asia/Kolkata", latitude: 19.1, longitude: 72.9),
        City(code: "NBO", name: "NAIROBI", zone: "Africa/Nairobi", latitude: -1.3, longitude: 36.9),
        City(code: "JFK", name: "NEW YORK", zone: "America/New_York", latitude: 40.6, longitude: -73.8),
        City(code: "OSL", name: "OSLO", zone: "Europe/Oslo", latitude: 60.2, longitude: 11.1),
        City(code: "CDG", name: "PARIS", zone: "Europe/Paris", latitude: 49.0, longitude: 2.5),
        City(code: "KEF", name: "REYKJAVIK", zone: "Atlantic/Reykjavik", latitude: 64.0, longitude: -22.6),
        City(code: "GIG", name: "RIO", zone: "America/Sao_Paulo", latitude: -22.8, longitude: -43.2),
        City(code: "FCO", name: "ROME", zone: "Europe/Rome", latitude: 41.8, longitude: 12.2),
        City(code: "SFO", name: "SAN FRANCISCO", zone: "America/Los_Angeles", latitude: 37.6, longitude: -122.4),
        City(code: "SCL", name: "SANTIAGO", zone: "America/Santiago", latitude: -33.4, longitude: -70.8),
        City(code: "GRU", name: "SAO PAULO", zone: "America/Sao_Paulo", latitude: -23.4, longitude: -46.5),
        City(code: "SEA", name: "SEATTLE", zone: "America/Los_Angeles", latitude: 47.4, longitude: -122.3),
        City(code: "ICN", name: "SEOUL", zone: "Asia/Seoul", latitude: 37.5, longitude: 126.5),
        City(code: "PVG", name: "SHANGHAI", zone: "Asia/Shanghai", latitude: 31.1, longitude: 121.8),
        City(code: "SIN", name: "SINGAPORE", zone: "Asia/Singapore", latitude: 1.4, longitude: 104.0),
        City(code: "ARN", name: "STOCKHOLM", zone: "Europe/Stockholm", latitude: 59.6, longitude: 17.9),
        City(code: "SYD", name: "SYDNEY", zone: "Australia/Sydney", latitude: -33.9, longitude: 151.2),
        City(code: "TPE", name: "TAIPEI", zone: "Asia/Taipei", latitude: 25.1, longitude: 121.2),
        City(code: "HND", name: "TOKYO", zone: "Asia/Tokyo", latitude: 35.5, longitude: 139.8),
        City(code: "YYZ", name: "TORONTO", zone: "America/Toronto", latitude: 43.7, longitude: -79.6),
        City(code: "YVR", name: "VANCOUVER", zone: "America/Vancouver", latitude: 49.2, longitude: -123.2),
        City(code: "VIE", name: "VIENNA", zone: "Europe/Vienna", latitude: 48.1, longitude: 16.6),
        City(code: "ZRH", name: "ZURICH", zone: "Europe/Zurich", latitude: 47.5, longitude: 8.5),
    ]
}
