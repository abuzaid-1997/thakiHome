import SwiftUI

// 🚰 كرت الخزان (النسخة الذكية)
struct WaterTankCard: View {
    let d: DeviceItem
    @State private var waveOffset = Angle(degrees: 0)
    
    // الحسابات
    var currentDistance: Double { Double(d.val ?? "0") ?? 0.0 }
    var currentWaterHeight: Double {
        let sensorHeight = d.tankHeight ?? 200.0
        let height = sensorHeight - currentDistance
        return max(0, height)
    }
    var waterPercentage: Double {
        let maxLevel = d.maxWaterLevel ?? 180.0
        let percent = (currentWaterHeight / maxLevel) * 100.0
        return min(max(percent, 0), 100)
    }
    var currentVolumeM3: String {
        let totalVol = d.tankVolume ?? 4.0
        let currentVol = (waterPercentage / 100.0) * totalVol
        return String(format: "%.1f m³", currentVol)
    }
    var batteryLevel: Int { 85 }
    
    var body: some View {
        ZStack {
            Color.cardBackground
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    Wave(offset: waveOffset, percent: waterPercentage)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.mainPurple.opacity(0.7)]),
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
            .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: waveOffset)
            .onAppear { waveOffset = Angle(degrees: 360) }
            
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "drop.fill").font(.title3).foregroundColor(.cyan)
                    Spacer()
                    HStack(spacing: 2) {
                        Text("\(batteryLevel)%").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                        Image(systemName: "battery.75").font(.caption2).foregroundColor(.gray)
                    }
                    .padding(4).background(.ultraThinMaterial).cornerRadius(8)
                }
                Spacer()
                Text("\(Int(waterPercentage))%")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(waterPercentage > 40 ? .white : .textPrimary)
                    .shadow(radius: waterPercentage > 40 ? 3 : 0)
                
                Text(currentVolumeM3)
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(waterPercentage > 40 ? .white.opacity(0.9) : .textSecondary)
            }
            .padding(15)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

// شكل الموجة
struct Wave: Shape {
    var offset: Angle
    var percent: Double
    var animatableData: Double {
        get { offset.degrees }
        set { offset = Angle(degrees: newValue) }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let lowestWave = 0.02; let highestWave = 1.00
        let newPercent = lowestWave + (highestWave - lowestWave) * (percent / 100)
        let waveHeight = 0.015 * rect.height
        let yOffset = CGFloat(1 - newPercent) * (rect.height - 4 * waveHeight) + 2 * waveHeight
        p.move(to: CGPoint(x: -5, y: yOffset + waveHeight * CGFloat(sin(offset.radians))))
        for angle in stride(from: offset.degrees, through: offset.degrees + 360, by: 5) {
            let x = CGFloat((angle - offset.degrees) / 360) * (rect.width + 10) - 5
            p.addLine(to: CGPoint(x: x, y: yOffset + waveHeight * CGFloat(sin(Angle(degrees: angle).radians))))
        }
        p.addLine(to: CGPoint(x: rect.width + 5, y: rect.height))
        p.addLine(to: CGPoint(x: -5, y: rect.height))
        p.closeSubpath(); return p
    }
}
