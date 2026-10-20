import SwiftUI

struct BloomHomeView: View {
    private enum Tab { case library, rediscover, map }
    @State private var selection = Tab.library

    var body: some View {
        TabView(selection: $selection) {
            LibraryView()
                .tabItem { Label("Libreria", systemImage: "tray.full") }.tag(Tab.library)
            PlacesMapView()
                .tabItem { Label("Mappa", systemImage: "map") }.tag(Tab.map)
            RediscoveryView { selection = .library }
                .tabItem { Label("Riscopri", systemImage: "sparkles") }.tag(Tab.rediscover)
        }.background(Color.bloomBackground.ignoresSafeArea())
    }
}
