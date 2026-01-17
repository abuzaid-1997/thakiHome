import SwiftUI

// MARK: - Layout Engine
struct AdvancedLayoutEngine: View {
    @Binding var devices: [DeviceItem]
    var viewModel: HomeViewModel
    var isEditing: Bool
    var onShowDetails: (DeviceItem) -> Void
    var onResize, onDelete: (DeviceItem)->Void
    var onStart: ()->Void
    var onToggle: (DeviceItem)->Void

    @State private var activeCardId: String? = nil

    var body: some View {
        VStack(spacing: 15) {
            let visibleDevices = devices.filter { $0.safeShowOnDashboard }
            let chunks = splitIntoChunks(devices: visibleDevices)
            
            ForEach(0..<chunks.count, id: \.self) { i in
                let chunk = chunks[i]
                let isRowActive = checkIsActive(chunk: chunk)
                
                Group {
                    if chunk.full {
                        ForEach(chunk.items) { d in cardView(d) }
                    } else {
                        HStack(alignment: .top, spacing: 15) {
                            VStack(spacing: 15) { ForEach(chunk.left) { d in cardView(d) } }.frame(maxWidth: .infinity)
                            VStack(spacing: 15) { ForEach(chunk.right) { d in cardView(d) } }.frame(maxWidth: .infinity)
                        }.padding(.horizontal)
                    }
                }
                .zIndex(isRowActive ? 1000 : Double(chunks.count - i))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: devices)
    }
    
    @ViewBuilder
    func cardView(_ d: DeviceItem) -> some View {
        DraggableCard(
            d: d,
            edit: isEditing,
            viewModel: viewModel,
            del: onDelete,
            start: onStart,
            onDragStateChanged: { isDragging in activeCardId = isDragging ? d.id : nil }
        )
        .padding(d.safeSize == .wide || d.safeSize == .big ? .horizontal : [])
        .id(d.id)
        .onTapGesture {
            if !isEditing {
                onToggle(d)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            if !isEditing { onStart() }
        }
    }
    
    func checkIsActive(chunk: Chunk) -> Bool {
        guard let activeId = activeCardId else { return false }
        if chunk.full { return chunk.items.contains(where: { $0.id == activeId }) }
        return chunk.left.contains(where: { $0.id == activeId }) || chunk.right.contains(where: { $0.id == activeId })
    }
    
    struct Chunk { var full: Bool; var items, left, right: [DeviceItem] }
    func splitIntoChunks(devices: [DeviceItem]) -> [Chunk] {
        var res: [Chunk] = []; var buf: [DeviceItem] = []
        for d in devices {
            if d.safeSize == .wide || d.safeSize == .big {
                if !buf.isEmpty { res.append(makeChunk(buf)); buf = [] }
                res.append(Chunk(full: true, items: [d], left: [], right: []))
            } else { buf.append(d) }
        }
        if !buf.isEmpty { res.append(makeChunk(buf)) }
        return res
    }
    func makeChunk(_ items: [DeviceItem]) -> Chunk {
        var l: [DeviceItem] = [], r: [DeviceItem] = []
        for (i, d) in items.enumerated() { if i % 2 == 0 { l.append(d) } else { r.append(d) } }
        return Chunk(full: false, items: [], left: l, right: r)
    }
}

// MARK: - Draggable Card Component
struct DraggableCard: View {
    let d: DeviceItem
    let edit: Bool
    var viewModel: HomeViewModel
    var del: (DeviceItem)->Void
    var start: ()->Void
    var onDragStateChanged: (Bool) -> Void
    
    @State private var dragTranslation: CGSize = .zero
    @State private var predictedSize: CardSize? = nil
    @State private var isJiggling = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 1. المحتوى
            ZStack {
                if d.type == "water_sensor" {
                    WaterTankCard(d: d)
                } else {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.cardBackground)
                        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 4)
                    
                    if d.safeSize == .small { SmallContent(d: d) }
                    else if d.safeSize == .wide { WideContent(d: d) }
                    else if d.safeSize == .tall { TallContent(d: d) }
                    else { BigContent(d: d) }
                }
            }
            .frame(width: frameSize(for: d.safeSize).width, height: frameSize(for: d.safeSize).height)
            
            // 2. الشبح
            if let targetSize = predictedSize, edit {
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(Color.mainPurple.opacity(0.15))
                    RoundedRectangle(cornerRadius: 24).stroke(Color.mainPurple, style: StrokeStyle(lineWidth: 3, dash: [8]))
                }
                .frame(width: frameSize(for: targetSize).width, height: frameSize(for: targetSize).height)
            }

            // 3. التحكم
            if edit {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .bold)).foregroundColor(.white).padding(8)
                            .background(Circle().fill(Color.mainPurple)).padding(6).shadow(radius: 2)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if isJiggling { isJiggling = false }
                                        if dragTranslation == .zero { onDragStateChanged(true) }
                                        dragTranslation = value.translation
                                        calculatePredictedSize()
                                    }
                                    .onEnded { value in
                                        if let target = predictedSize {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            viewModel.setDeviceSize(d, size: target)
                                        }
                                        onDragStateChanged(false)
                                        dragTranslation = .zero
                                        predictedSize = nil
                                        if edit { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isJiggling = true } }
                                    }
                            )
                    }
                }
                .frame(width: frameSize(for: d.safeSize).width, height: frameSize(for: d.safeSize).height)
                
                Button { del(d) } label: {
                    Image(systemName: "minus.circle.fill").font(.title2).foregroundColor(.red)
                        .background(Circle().fill(.white)).shadow(radius: 2)
                }
                .offset(x: -8, y: -8)
            }
        }
        .frame(width: frameSize(for: d.safeSize).width, height: frameSize(for: d.safeSize).height, alignment: .topLeading)
        .zIndex(predictedSize != nil ? 1000 : 0)
        .rotationEffect(.degrees(isJiggling ? 1.2 : 0))
        .animation(isJiggling ? .linear(duration: 0.14).repeatForever(autoreverses: true) : .default, value: isJiggling)
        .onChange(of: edit) { oldValue, newValue in isJiggling = newValue }
        .onAppear { if edit { isJiggling = true } }
    }
    
    func calculatePredictedSize() {
        let w = dragTranslation.width; let h = dragTranslation.height; let sensitivity: CGFloat = 30
        if w > sensitivity && h > sensitivity { predictedSize = .big }
        else if w > sensitivity { predictedSize = .wide }
        else if h > sensitivity { predictedSize = .tall }
        else if w < -sensitivity || h < -sensitivity { predictedSize = .small }
    }
    
    func frameSize(for size: CardSize) -> CGSize {
        let baseW: CGFloat = 165; let baseH: CGFloat = 110; let spacing: CGFloat = 15
        switch size {
        case .small: return CGSize(width: baseW, height: baseH)
        case .wide:  return CGSize(width: (baseW * 2) + spacing, height: baseH)
        case .tall:  return CGSize(width: baseW, height: (baseH * 2) + spacing)
        case .big:   return CGSize(width: (baseW * 2) + spacing, height: (baseH * 2) + spacing)
        }
    }
}
