import SwiftUI

struct SmallContent: View {
    let d: DeviceItem
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: d.safeIcon).foregroundColor(d.safeIsActive ? .mainPurple : .textSecondary)
                Spacer()
                Circle().fill(d.safeIsActive ? .green : .gray.opacity(0.3)).frame(width:8)
            }
            Spacer()
            Text(d.name).bold().lineLimit(1).font(.system(size: 15)).foregroundColor(.textPrimary)
            Text(d.safeStatus).font(.caption).foregroundColor(.textSecondary)
        }.padding(15)
    }
}

struct WideContent: View {
    let d: DeviceItem
    var body: some View {
        HStack {
            Image(systemName: d.safeIcon).font(.title2).foregroundColor(d.safeIsActive ? .mainPurple : .textSecondary).frame(width: 50)
            VStack(alignment: .leading) {
                Text(d.name).bold().foregroundColor(.textPrimary)
                Text(d.safeStatus).font(.caption).foregroundColor(.textSecondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { d.safeIsActive }, set: { _ in })).labelsHidden().disabled(true)
        }.padding()
    }
}

struct TallContent: View {
    let d: DeviceItem
    var body: some View {
        VStack {
            Image(systemName: d.safeIcon).font(.largeTitle).foregroundColor(d.safeIsActive ? .mainPurple : .textSecondary).padding(.top)
            Spacer()
            Text(d.name).bold().foregroundColor(.textPrimary)
            Text(d.safeStatus).bold().padding(.bottom).foregroundColor(.textSecondary)
        }.padding()
    }
}

struct BigContent: View {
    let d: DeviceItem
    var body: some View {
        VStack(alignment: .leading) {
            Image(systemName: d.safeIcon).font(.largeTitle).foregroundColor(d.safeIsActive ? .mainPurple : .textSecondary)
            Spacer()
            Text(d.name).bold().foregroundColor(.textPrimary)
            Text(d.safeStatus).font(.title2).bold().foregroundColor(.textSecondary)
        }.padding(20)
    }
}
