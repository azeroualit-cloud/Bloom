import SwiftUI
import SwiftData
import MapKit

@MainActor
struct PlacesMapView: View {
    @Query(sort: \CapturedLink.capturedAt, order: .reverse) private var notes: [CapturedLink]
    @State private var camera: MapCameraPosition = .automatic
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
            Group {
                if groups.isEmpty {
                    ContentUnavailableView("Nessun luogo salvato", systemImage: "map", description: Text("Aggiungi un luogo a una nota, oppure salva un link di Maps con coordinate. I geotag dei post social non arrivano nel link condiviso."))
                } else {
                    Map(position: $camera, selection: $selectedID) {
                        ForEach(groups) { group in
                            Marker(group.notes.count > 1 ? "\(group.place.name) · \(group.notes.count) note" : group.place.name,
                                   coordinate: CLLocationCoordinate2D(latitude: group.place.latitude, longitude: group.place.longitude))
                                .tag(group.id)
                        }
                    }.mapControls { MapCompass(); MapScaleView() }
                        .safeAreaInset(edge: .bottom) {
                            if let selected {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(selected.place.name).font(.headline).lineLimit(2)
                                        Spacer()
                                        Button { selectedID = nil } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Chiudi luogo")
                                    }
                                    ScrollView(.horizontal) {
                                        HStack {
                                            ForEach(selected.notes) { note in
                                                Button(note.displayTitle) { opened = note }.buttonStyle(.bordered).frame(minHeight: 44)
                                            }
                                        }
                                    }
                                    Button("Apri in Mappe", systemImage: "arrow.triangle.turn.up.right.diamond") { openMaps(selected.place) }.frame(minHeight: 44)
                                }.padding(.horizontal, 16).background(.regularMaterial)
                            }
                        }
                }
            }.navigationTitle("Mappa").navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $opened) { ContentViewer(item: $0) }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) { Button("Elenco luoghi", systemImage: "list.bullet") { showingList = true }.disabled(groups.isEmpty).accessibilityIdentifier("map-places-list") }
                    ToolbarItem(placement: .topBarLeading) { Button("Mostra tutti", systemImage: "arrow.up.left.and.arrow.down.right") { selectedID = nil; camera = .automatic }.disabled(groups.isEmpty) }
                }
                .sheet(isPresented: $showingList) {
                    NavigationStack {
                        List {
                            ForEach(groups) { group in
                                Section(group.place.name) {
                                    ForEach(group.notes) { note in
                                        NavigationLink { ContentViewer(item: note) } label: { Text(note.displayTitle) }
                                    }
                                }
                            }
                        }.navigationTitle("Luoghi salvati").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fine") { showingList = false } } }
                    }
                }
                .onChange(of: groups.map(\.id)) { _, ids in if let selectedID, !ids.contains(selectedID) { self.selectedID = nil } }
                .onChange(of: notes.filter { !$0.isArchived }.map(\.id)) { _, ids in if opened?.modelContext == nil || opened?.isDeleted == true || opened?.isArchived == true { opened = nil } }
        }
    }
    private func openMaps(_ place: NotePlace) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)))
        item.name = place.name
        item.openInMaps()
    }
}
