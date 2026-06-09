import SwiftUI

@main
struct Pocket_Catch_RaterApp: App {
    @State private var dataStore: PokemonDataStore

    init() {
        let database = try! PokemonDatabase()
        let repository = PokemonRepository(database: database)
        _dataStore = State(initialValue: PokemonDataStore(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(dataStore: dataStore)
                .task {
                    await dataStore.bootstrap()
                }
        }
    }
}
