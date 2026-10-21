import SwiftUI
import SwiftData
import MapKit
import UniformTypeIdentifiers

@MainActor
struct PlacesMapView: View {
    @Query(sort: \CapturedLink.capturedAt, order: .reverse) private var notes: [CapturedLink]
    @State private var fitRequest = 0
    @State private var selectedID: String?
    @State private var showingList = false
    @State private var opened: CapturedLink?
    private struct PlaceGroup: Identifiable {
        let id: String
        let place: NotePlace
        var notes: [CapturedLink]
    }
    private var groups: [PlaceGroup] {
        var values: [String: PlaceGroup] = [:]
        for note in notes where !note.isArchived && !note.isDeleted {
            guard let place = note.place else { continue }
            let key = "\((place.latitude * 100_000).rounded())/\((place.longitude * 100_000).rounded())"
            if values[key] != nil { values[key]?.notes.append(note) }
            else { values[key] = PlaceGroup(id: key, place: place, notes: [note]) }
        }
        return values.values.sorted { $0.place.name.localizedStandardCompare($1.place.name) == .orderedAscending }
    }
    private var selected: PlaceGroup? { groups.first { $0.id == selectedID } }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                mapHeader
                mapContent.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            }
                .bloomCanvas().navigationTitle("Mappa").navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: $opened) { ContentViewer(item: $0).toolbar(.visible, for: .navigationBar) }
                .sheet(isPresented: $showingList) { placesList }
                .onChange(of: groups.map(\.id)) { _, ids in
                    if let selectedID, !ids.contains(selectedID) { self.selectedID = nil }
                }
                .onChange(of: notes.filter { !$0.isArchived }.map(\.id)) { _, _ in
                    if opened?.modelContext == nil || opened?.isDeleted == true || opened?.isArchived == true { opened = nil }
                }
        }
    }
    @ViewBuilder private var mapContent: some View {
        if groups.isEmpty {
            ContentUnavailableView("Nessun luogo salvato", systemImage: "map", description: Text("Aggiungi un luogo a una nota, oppure salva un link di Maps con coordinate. I geotag dei post social non arrivano nel link condiviso."))
        } else {
            mapCanvas.safeAreaInset(edge: .bottom) { selectionPanel }
        }
    }
    private var mapCanvas: some View {
        ClusteredPlacesMap(places: groups.map { group in
            PlaceMapAnnotation(id: group.id, place: group.place, count: group.notes.count)
        }, selectedID: selectedID, fitRequest: fitRequest) { selectedID = $0 }
    }
    private var mapHeader: some View {
        BloomPageHeader(title: "Mappa", subtitle: "\(groups.count) luoghi", leading: {
            Button { selectedID = nil; fitRequest += 1 } label: {
                Text("Mostra tutti").frame(maxWidth: .infinity, minHeight: BloomLayout.touch)
                    .background(Color.bloomSurface, in: RoundedRectangle(cornerRadius: BloomLayout.gap))
            }.disabled(groups.isEmpty).accessibilityLabel("Mostra tutti").accessibilityIdentifier("map-show-all")
        }, trailing: {
            Button { showingList = true } label: {
                Text("Luoghi").frame(maxWidth: .infinity, minHeight: BloomLayout.touch)
                    .background(Color.bloomSurface, in: RoundedRectangle(cornerRadius: BloomLayout.gap))
            }.disabled(groups.isEmpty).accessibilityLabel("Elenco luoghi salvati").accessibilityIdentifier("map-places-list")
        }).accessibilityIdentifier("map-header")
    }
    @ViewBuilder private var selectionPanel: some View {
        if let selected {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.place.name).font(.headline).lineLimit(2)
                        Text(ContentLabels.noteCount(selected.notes.count)).font(.caption).foregroundStyle(Color.bloomText.opacity(0.85))
                    }
                    Spacer()
                    Button { openMaps(selected.place) } label: {
                        Image(systemName: "arrow.up.right.square").frame(width: BloomLayout.touch, height: BloomLayout.touch)
                    }.accessibilityLabel("Apri in Mappe")
                    Button { selectedID = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Chiudi luogo")
                }
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(selected.notes) { note in
                            Button { opened = note } label: {
                                HStack(spacing: 8) {
                                    MapPostMarker(item: note, count: 1, selected: false)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(note.displayTitle).font(.subheadline.weight(.semibold)).lineLimit(2)
                                        Text("Apri nota").font(.caption).foregroundStyle(.secondary)
                                    }
                                }.padding(4)
                            }.buttonStyle(.plain).frame(minHeight: 44).accessibilityIdentifier("map-open-note-\(note.id)")
                        }
                    }
                }.scrollIndicators(.hidden)
            }.padding(BloomLayout.margin).background(Color.bloomSurface)
        }
    }
    private var placesList: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section(group.place.name) {
                        ForEach(group.notes) { note in
                            NavigationLink { ContentViewer(item: note) } label: { Text(note.displayTitle) }
                        }
                    }
                }
            }.bloomCanvas().navigationTitle("Luoghi salvati").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fine") { showingList = false } } }
        }
    }
    private func openMaps(_ place: NotePlace) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)))
        item.name = place.name
        item.openInMaps()
    }
}

/// Bounded thumbnails reuse the local image decoders; originals are never loaded at full size on the map.
@MainActor
private struct MapPostMarker: View {
    @Environment(\.modelContext) private var context
    let item: CapturedLink
    let count: Int
    let selected: Bool
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.bloomSurface.overlay {
                if item.modelContext != nil && !item.isDeleted { preview }
            }.frame(width: 56, height: 56).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? AnyShapeStyle(BloomBrand.gradient) : AnyShapeStyle(Color.bloomText), lineWidth: selected ? 3 : 2) }
            if count > 1 {
                Text("\(count)").font(.caption2.bold()).foregroundStyle(Color.bloomBackground)
                    .padding(4).background(BloomBrand.gradient, in: Capsule()).offset(x: 6, y: -6)
            }
        }.padding(6).shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            .accessibilityElement(children: .ignore).accessibilityLabel("\(item.displayTitle), \(ContentLabels.noteCount(count)) in questo luogo")
            .accessibilityIdentifier("map-post-preview-\(item.id)")
            .task(id: item.id) {
                guard item.modelContext != nil, !item.isDeleted else { return }
                LinkPreviewController.shared.prepare(for: item, in: context)
            }
    }
    @ViewBuilder private var preview: some View {
        if let data = item.previewImageData, item.previewSourceURL == item.allLinks.first?.absoluteString {
            CachedPreviewImage(data: data, label: item.displayTitle, maxPixel: 192, contentMode: .fill)
        } else if item.kind == .image {
            AttachmentThumbnail(item: item, maximumPixelSize: 192, contentMode: .fill)
        } else if let file = item.noteFiles.first(where: { UTType($0.type)?.conforms(to: .image) == true }) {
            FramedImage(data: file.data, framing: file.framing ?? ImageFraming(), maximumPixel: 192, contentMode: .fill)
        } else {
            VStack(spacing: 4) {
                Image(systemName: item.kind.symbol).foregroundStyle(BloomBrand.gradient)
                Text(item.displayTitle).font(.system(size: 9, weight: .medium)).lineLimit(2).foregroundStyle(Color.bloomText)
            }.padding(4)
        }
    }
}
