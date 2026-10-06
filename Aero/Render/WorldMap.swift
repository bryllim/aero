import SwiftUI

/// A dotted world map: land sampled onto a grid from simplified coastlines,
/// shaded by daylight, with the chosen destinations marked.
enum WorldMap {
    // The window starts west of Alaska so the Bering Strait, not Siberia, is split by the edge.
    static let west = -170.0
    static let north = 80.0
    static let south = -56.0
    static let aspect = CGFloat(360 / (north - south))

    struct Grid {
        let columns: Int
        let rows: Int
        let land: [Bool]
    }

    private static var cache: [Double: Grid] = [:]
    private static let lock = NSLock()

    /// Land mask with one dot per `step` degrees.
    static func grid(step: Double) -> Grid {
        lock.lock()
        defer { lock.unlock() }
        if let grid = cache[step] { return grid }

        let columns = Int(360 / step), rows = Int((north - south) / step)
        var land = [Bool](repeating: false, count: columns * rows)
        for row in 0..<rows {
            let latitude = north - (Double(row) + 0.5) * step
            for column in 0..<columns {
                let longitude = west + (Double(column) + 0.5) * step
                land[row * columns + column] = isLand(longitude, latitude) || isLand(longitude - 360, latitude)
            }
        }
        let grid = Grid(columns: columns, rows: rows, land: land)
        cache[step] = grid
        return grid
    }

    /// Position in the map's unit square.
    static func position(latitude: Double, longitude: Double) -> CGPoint {
        var offset = (longitude - west).truncatingRemainder(dividingBy: 360)
        if offset < 0 { offset += 360 }
        return CGPoint(x: offset / 360, y: (north - latitude) / (north - south))
    }

    /// Where the sun is directly overhead.
    static func subsolarPoint(at date: Date) -> (latitude: Double, longitude: Double) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let day = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hours = Double(parts.hour!) + Double(parts.minute!) / 60 + Double(parts.second!) / 3600

        let declination = -23.44 * cos(2 * .pi * (day + 10) / 365)
        let b = 2 * .pi * (day - 81) / 364
        let equationOfTime = 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b)  // minutes
        return (declination, (12 - hours - equationOfTime / 60) * 15)
    }

    private static func isLand(_ longitude: Double, _ latitude: Double) -> Bool {
        land.contains { contains($0, longitude, latitude) } && !water.contains { contains($0, longitude, latitude) }
    }

    /// Even-odd test against a polygon stored as flat longitude, latitude pairs.
    private static func contains(_ polygon: [Double], _ x: Double, _ y: Double) -> Bool {
        let count = polygon.count / 2
        var inside = false
        var j = count - 1
        for i in 0..<count {
            let xi = polygon[i * 2], yi = polygon[i * 2 + 1]
            let xj = polygon[j * 2], yj = polygon[j * 2 + 1]
            if (yi > y) != (yj > y), x < (xj - xi) * (y - yi) / (yj - yi) + xi { inside.toggle() }
            j = i
        }
        return inside
    }

    // Simplified coastlines as longitude, latitude pairs. Eastern Siberia runs past 180°.
    private static let land: [[Double]] = [
        // North America
        [-168, 66, -162, 70, -156, 71, -141, 70, -128, 70, -115, 68.5, -110, 68, -95, 68.5, -94, 72, -85, 69.5,
         -82, 67, -87, 64.5, -94, 61, -94.5, 58.5, -92, 57, -85, 55.3, -82, 53, -80, 51.3, -79, 54.5, -77, 56,
         -78, 58.5, -77.5, 62.5, -73, 62, -70, 61, -69, 58.8, -65, 60, -61, 56.5, -57, 53, -56, 51.5, -60, 50,
         -66, 50.2, -69, 48, -65, 49, -64.5, 47.5, -61, 46, -60, 46, -65.5, 43.5, -67, 45, -70, 43.7, -70.5, 41.8,
         -74, 40.5, -75.5, 38, -76, 35, -81, 31.5, -80.2, 27, -80.5, 25.2, -82, 26.5, -82.8, 29.5, -85, 29.7,
         -89, 30.2, -90, 29, -94, 29.5, -97.3, 27.5, -97.7, 22.5, -96, 19, -94.5, 18.3, -91, 18.7, -90.5, 21,
         -87, 21.5, -87.7, 18, -88.5, 16, -84, 15.8, -83.3, 12.5, -83.7, 10.5, -82, 9, -79.5, 9.5, -77.3, 8.5,
         -77.5, 7.5, -80.5, 7.3, -83, 8.3, -85.7, 10, -87.5, 13, -91.5, 14, -94.5, 16.2, -99, 16.7, -105.5, 20,
         -105.5, 22.5, -108.5, 25.5, -111, 28, -113, 31, -114.5, 31.5, -112.7, 28, -110, 24.5, -109.8, 23,
         -112.2, 24.8, -114.5, 28, -116, 30.5, -117, 32.5, -120.5, 34.5, -122.5, 37.5, -124.3, 40.3, -124, 46.5,
         -124.7, 48.4, -123, 49, -127, 51, -130, 54.5, -134, 58, -140, 60, -147, 61, -152, 59, -157, 57, -163, 55,
         -160, 58.5, -165, 61, -164, 63.5, -161, 64.5, -166, 65.5],
        // South America
        [-77.3, 8.5, -75.5, 10.8, -72, 12.3, -68, 11, -62, 10.7, -57, 6, -51.5, 4.5, -50, 0, -44, -2.5, -37, -4.8,
         -35, -7.5, -37.5, -12, -39, -17, -41, -22, -45, -23.8, -48.5, -27, -51, -31, -53.5, -34.2, -57, -34.5,
         -57.5, -38, -62, -39, -65, -41, -63.5, -42.5, -67, -46, -66, -48, -69, -51, -68.3, -53, -66, -55,
         -71, -54.5, -75, -50, -74, -45, -73, -40, -73.5, -37, -71.5, -31, -70.3, -18.5, -76, -14, -81, -6,
         -80, -2.5, -80, 1, -77.5, 4, -77.5, 7.5],
        // Europe and Asia
        [-9, 37, -9.3, 39, -8.8, 43.2, -1.8, 43.4, -1.2, 46, -4.7, 48.4, -1.5, 48.7, -1.3, 49.7, 1.7, 50.9, 4, 52,
         5, 53.3, 8.5, 53.7, 8.2, 57, 10.5, 57.7, 10, 55, 12, 54.2, 14, 54, 18.5, 54.7, 21, 55.5, 21, 57.5,
         24, 57.3, 23.5, 59.3, 28, 59.7, 30, 60, 26, 60.5, 22.5, 60, 21.3, 61.5, 22, 63.5, 25.3, 65, 24, 65.8,
         21.5, 64.5, 17.5, 62, 17.2, 60.5, 18.8, 59.8, 16.5, 56.5, 14.3, 55.5, 12.8, 55.5, 11.2, 59, 8, 58,
         5.5, 59, 5, 62, 10, 64, 14, 67.5, 19, 69.8, 25.5, 71, 30, 70, 33, 69.3, 41, 67.5, 40, 66, 34, 66.5,
         35, 64.3, 40, 64.7, 44, 66.2, 44, 68.3, 54, 68.3, 60, 69, 68, 69, 69, 73, 80, 73.5, 87, 75.5, 104, 77.7,
         113, 74, 125, 73.5, 130, 71, 140, 72.7, 150, 71.5, 160, 69.7, 170, 70, 180, 69, 190, 67, 190, 65.5,
         182, 65, 179, 62.5, 170, 60, 164, 60, 163, 57, 162, 54.5, 157, 51, 156, 57, 160, 61.5, 155, 59.5,
         143, 59.3, 135, 54.5, 140.5, 53, 141, 49, 138, 46, 133, 43, 130, 42.5, 128, 40, 129.5, 37, 129, 35.2,
         126.3, 34.5, 126, 37.5, 125, 39.7, 121.5, 39, 122, 40.7, 118, 39, 119, 37.3, 122.5, 37, 119.5, 34.7,
         122, 31, 121.5, 28, 119, 25, 114, 22.3, 110.5, 21.3, 108, 21.5, 106, 19, 108.5, 15.5, 109.3, 12, 106.5, 9,
         104.8, 8.7, 105, 10.3, 102.5, 12, 100.8, 13.3, 99.5, 10.5, 100.5, 7.5, 103, 5, 104.2, 1.4, 100.5, 4,
         98.5, 8, 98.5, 13, 97.5, 16.5, 94.3, 16, 94, 19, 92, 21.5, 89, 22, 87, 21, 82.5, 16.5, 80.2, 15,
         80, 10.5, 77.5, 8.1, 74.5, 14, 72.8, 19, 72.5, 21.5, 70, 21, 69, 22.5, 67, 24.5, 61.5, 25.2, 57, 25.7,
         56.5, 27, 51.5, 28, 48.5, 30, 50, 26.5, 51.5, 24.3, 54, 24, 56.3, 26.2, 56.5, 24.5, 59.8, 22.5, 57.5, 19,
         55, 17, 52, 16, 45, 12.8, 43.3, 12.7, 42.5, 16.5, 39, 21.5, 35, 28, 34, 27.8, 32.5, 30, 32.3, 31.3,
         34.5, 31.5, 35.8, 36, 36, 36.8, 32.5, 36.2, 30.5, 36.3, 27.5, 36.8, 26.3, 38.5, 26.5, 40.3, 29, 41,
         31, 41.2, 35, 42, 38.5, 41, 41.5, 41.6, 41, 43, 37, 45, 38.5, 47.2, 35, 46, 36, 45, 33.5, 44.5, 33, 46,
         30.7, 46.5, 29.7, 45.2, 28, 43.5, 28, 42, 28.8, 41.2, 26.2, 40.8, 24, 40.8, 22.8, 40.4, 23.5, 38,
         23, 36.5, 21.5, 37, 21, 39, 19.5, 40.5, 19.5, 42, 16, 43.5, 13.7, 45.5, 12.3, 45.3, 12.5, 44, 14, 42.5,
         16, 41.8, 18.5, 40.2, 16.8, 40.4, 17.1, 39, 16, 38, 15.8, 40, 13, 41.3, 10.5, 43, 8.8, 44.4, 6.5, 43.2,
         4, 43.5, 3.1, 42.4, 0.5, 40.5, -0.3, 39, -0.7, 37.6, -2.2, 36.7, -5.3, 36.1, -6.3, 36.8],
        // Africa
        [-5.9, 35.8, -2, 35.2, 3, 36.8, 10, 37.2, 11, 33.5, 15, 32.3, 20, 30.8, 20, 32.8, 25, 31.7, 29, 31,
         32.3, 31.3, 32.5, 30, 33.5, 28, 35.5, 24, 37.2, 21, 38.5, 18, 41, 14.8, 43.2, 12.2, 43.3, 11.4, 47, 11.2,
         51.2, 12, 50.5, 9, 47.5, 4, 42, -1.5, 39.5, -5, 39.5, -10, 40.7, -15, 35, -20.5, 35.5, -24, 32.8, -26,
         32.5, -29, 28, -33, 25.5, -34, 20, -34.8, 18.3, -34, 17.5, -30, 14.5, -22.5, 11.8, -17, 13.5, -12,
         12.3, -6, 9.3, -1, 9.7, 3.5, 8.5, 4.5, 5, 6, 1, 6, -4, 5.2, -7.7, 4.4, -11.5, 7, -13.3, 9.5, -16.7, 12.5,
         -17.5, 14.7, -16.3, 19, -17, 21, -14.5, 26, -9.7, 30, -9.3, 32.5],
        // Australia
        [114, -22, 113.5, -26, 115, -31.5, 115, -34.3, 118, -35, 123.5, -34, 129, -31.7, 134, -32.5, 136, -35,
         138, -33, 137.8, -35.7, 140.5, -38, 146.3, -39, 150, -37.5, 151.3, -33.5, 153.5, -28, 153, -25, 149, -21,
         146, -19, 145.3, -15, 142.5, -10.7, 141.5, -13, 141, -17, 139.5, -17.5, 135.5, -15, 137, -12,
         132.5, -11.3, 130, -12.5, 129, -15, 125.5, -14, 122, -17.5, 119, -20],
        // Greenland
        [-73, 78, -60, 82, -30, 83.5, -18, 80, -20, 74, -23, 70, -32, 68, -40, 65, -43, 60, -48, 61, -52, 65,
         -54, 69, -58, 75, -68, 76],
        // Canadian Arctic: Baffin, Victoria, Banks, Ellesmere
        [-80, 73.5, -72, 71.5, -62, 66.5, -65, 62, -73, 64.5, -78, 66, -74, 68, -85, 70.5, -89, 73.5],
        [-117, 73, -105, 73, -102, 69.5, -115, 69],
        [-125, 74.5, -116, 74.5, -117, 71.5, -125, 71.5],
        [-90, 82, -62, 82.5, -75, 78, -80, 76, -90, 77],
        // Newfoundland, Cuba, Hispaniola, Hawaii
        [-59, 47.6, -53, 46.7, -52.7, 48.5, -55.5, 51.5, -57.5, 50.5],
        [-85, 22, -80, 23.2, -74.2, 20.2, -77.5, 19.8, -82, 21.5],
        [-74.4, 19.8, -68.5, 18.6, -71.5, 17.7, -74.4, 18.5],
        [-156.2, 19, -154.8, 19.5, -155.8, 20.3],
        // Iceland, Great Britain, Ireland, Svalbard, Novaya Zemlya
        [-24, 65.5, -22, 66.4, -16, 66.5, -13.6, 65, -18.5, 63.4, -22.7, 63.8],
        [-5.5, 50, 1.3, 51.2, 1.7, 52.8, 0, 53.5, -1.5, 55, -2, 57.5, -3.3, 58.6, -5, 58.5, -6, 56.5, -4.8, 54.8,
         -3, 53.4, -4.5, 53.2, -5, 51.7, -3, 51.4],
        [-10, 52, -6.3, 52.2, -6, 54, -5.6, 55, -8, 55.3, -10, 54],
        [11, 79.5, 20, 80.5, 27, 80, 21, 77.5, 15, 76.7],
        [51.5, 71, 55, 70.7, 57.5, 72.5, 68, 76.8, 60, 76.3, 53, 73.5],
        // Sicily, Sardinia
        [12.5, 38, 15.6, 38.2, 15, 36.7],
        [8.2, 41, 9.7, 41, 9.5, 39.2, 8.5, 39],
        // Madagascar, Sri Lanka
        [49.3, -12, 50.5, -15.5, 47.5, -25, 44, -25, 43.5, -21.5, 44.5, -16.2, 47, -15],
        [80, 9.7, 81.8, 7.5, 80.6, 6, 79.8, 7.5],
        // Japan: Honshu with Kyushu and Shikoku, Hokkaido; Sakhalin; Taiwan; Hainan
        [130, 31.3, 131.5, 31.3, 132, 33.5, 135.7, 33.5, 137, 34.6, 139.8, 35, 141, 36.8, 142, 39.5, 141.3, 41.4,
         140, 40.8, 139.5, 38.3, 137, 37.2, 136, 36, 133, 35.5, 131, 34.3, 129.7, 33],
        [140, 41.6, 141.2, 45.3, 145.3, 43.5, 143.5, 42, 141, 42.5],
        [142, 46, 143.5, 49, 143, 54, 142, 53, 142, 49],
        [120.2, 23, 121.5, 25.2, 122, 24, 120.8, 22],
        [108.7, 19.3, 110.8, 20, 110.3, 18.3, 108.8, 18.5],
        // Philippines: Luzon, Visayas, Mindanao
        [120.5, 18.5, 122.2, 18.4, 122, 16, 124, 13, 123, 13.2, 121, 13.8, 120, 16],
        [122, 11.8, 125.5, 12.5, 125, 10, 123, 9.5],
        [122, 7, 125.5, 9.8, 126.5, 7, 125.5, 5.8, 123.5, 7.5],
        // Sumatra, Java, Borneo, Sulawesi, New Guinea
        [95.3, 5.5, 98, 4, 103.5, -1, 106, -5.8, 104.5, -5.8, 101, -2.5, 97.5, 1.5],
        [105.3, -6.5, 108.5, -6.6, 111, -6.5, 114.5, -7.8, 114.3, -8.7, 108, -7.8, 105.5, -7],
        [109, 1.5, 111.3, 2.5, 114.5, 5, 117, 7, 119, 5, 117.8, 1, 116.5, -3.8, 114.5, -3.8, 111.5, -3,
         110, -1.5, 109, 0],
        [119.3, 1, 125, 1.5, 123, -5.5, 119.3, -5.5],
        [131, -0.8, 138, -1.7, 141, -2.6, 145.8, -5, 147.7, -6.5, 150.8, -10.5, 147, -9.8, 143.5, -8.5, 141, -9.2,
         138, -8.3, 138, -5.5, 133, -4, 132, -2.8],
        // Tasmania, New Zealand
        [144.7, -40.8, 148.3, -40.9, 148, -43.3, 146, -43.6, 145.2, -42.2],
        [172.7, -34.5, 175.5, -36.3, 178.5, -37.7, 177, -39.5, 175.2, -41.6, 173.8, -39.3, 174.7, -37.5],
        [172.7, -40.6, 174.3, -41.7, 171, -44.2, 170.5, -46, 168.3, -46.7, 166.5, -45.8, 168.5, -44, 171, -42.3],
    ]

    // Inland seas cut out of the land above.
    private static let water: [[Double]] = [
        // Caspian Sea
        [49, 46.5, 53, 46.8, 53, 45, 50.5, 44.5, 53.5, 41, 53.8, 37.5, 50, 37, 49, 40.5, 47.5, 43, 47, 45],
    ]
}

enum MapRenderer {
    private static let shades = 8

    static func draw(_ context: inout GraphicsContext, in rect: CGRect, settings: AeroSettings, date: Date) {
        let grid = WorldMap.grid(step: settings.mapDetail.step)
        let foreground = Color(hex: settings.foregroundHex)
        let pitch = rect.width / CGFloat(grid.columns)
        let dot = pitch * settings.dotFill
        let inset = (pitch - dot) / 2

        // Land, bucketed by how much daylight each dot is getting.
        let sun = WorldMap.subsolarPoint(at: date)
        let sunLatitude = sun.latitude * .pi / 180
        var paths = [Path](repeating: Path(), count: shades)
        for row in 0..<grid.rows {
            let latitude = (WorldMap.north - (Double(row) + 0.5) * settings.mapDetail.step) * .pi / 180
            for column in 0..<grid.columns where grid.land[row * grid.columns + column] {
                var shade = shades - 1
                if settings.mapDaylight {
                    let longitude = WorldMap.west + (Double(column) + 0.5) * settings.mapDetail.step
                    let elevation = sin(latitude) * sin(sunLatitude)
                        + cos(latitude) * cos(sunLatitude) * cos((longitude - sun.longitude) * .pi / 180)
                    let t = min(max((elevation + 0.12) / 0.2, 0), 1)
                    shade = Int((t * t * (3 - 2 * t) * Double(shades - 1)).rounded())
                }
                let dotRect = CGRect(x: rect.minX + CGFloat(column) * pitch + inset,
                                     y: rect.minY + CGFloat(row) * pitch + inset, width: dot, height: dot)
                switch settings.dotShape {
                case .round: paths[shade].addEllipse(in: dotRect)
                case .square: paths[shade].addRect(dotRect)
                }
            }
        }
        let night = 0.2, day = settings.mapDaylight ? 0.8 : 0.55
        for (shade, path) in paths.enumerated() where !path.isEmpty {
            let opacity = night + (day - night) * Double(shade) / Double(shades - 1)
            context.fill(path, with: .color(foreground.opacity(opacity)))
        }

        // Destinations: clear a little space in the dots, then draw a ringed marker and its code.
        let cities = settings.cities.compactMap(City.find)
        let centers = cities.map { city -> CGPoint in
            let unit = WorldMap.position(latitude: city.latitude, longitude: city.longitude)
            return CGPoint(x: rect.minX + unit.x * rect.width, y: rect.minY + unit.y * rect.height)
        }
        let ring = max(pitch * 1.25, 3)
        let pixel = max(pitch * 0.3, 1)
        let labelHeight = pixel * CGFloat(PixelFont.rows)

        func labelOrigin(_ city: City, _ center: CGPoint) -> CGPoint {
            let width = CGFloat(PixelFont.columns(city.code)) * pixel
            let fitsRight = center.x + ring * 1.7 + width <= rect.maxX
            return CGPoint(x: fitsRight ? center.x + ring * 1.7 : center.x - ring * 1.7 - width,
                           y: center.y - labelHeight / 2)
        }

        var knockout = context
        knockout.blendMode = .clear
        for (city, center) in zip(cities, centers) {
            knockout.fill(Path(ellipseIn: CGRect(x: center.x - ring * 1.45, y: center.y - ring * 1.45,
                                                 width: ring * 2.9, height: ring * 2.9)), with: .color(.black))
            if settings.mapLabels {
                let origin = labelOrigin(city, center)
                let width = CGFloat(PixelFont.columns(city.code)) * pixel
                knockout.fill(Path(CGRect(x: origin.x, y: origin.y, width: width, height: labelHeight)
                                    .insetBy(dx: -pixel * 1.5, dy: -pixel * 1.5)), with: .color(.black))
            }
        }

        var markers = Path(), rings = Path(), labels = Path()
        for (city, center) in zip(cities, centers) {
            markers.addEllipse(in: CGRect(x: center.x - ring * 0.42, y: center.y - ring * 0.42,
                                          width: ring * 0.84, height: ring * 0.84))
            rings.addEllipse(in: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2))
            guard settings.mapLabels else { continue }
            let origin = labelOrigin(city, center)
            for (row, bits) in PixelFont.bitmap(city.code).enumerated() {
                for (column, on) in bits.enumerated() where on {
                    labels.addRect(CGRect(x: origin.x + CGFloat(column) * pixel, y: origin.y + CGFloat(row) * pixel,
                                          width: pixel, height: pixel))
                }
            }
        }
        if settings.glow > 0.01 {
            var halo = context
            halo.addFilter(.blur(radius: ring * 0.9 * settings.glow))
            halo.drawLayer { $0.fill(markers, with: .color(foreground)) }
        }
        context.fill(markers, with: .color(foreground))
        context.stroke(rings, with: .color(foreground.opacity(0.9)), lineWidth: max(ring * 0.14, 0.75))
        context.fill(labels, with: .color(foreground))
    }
}
