import SwiftUI

struct ContentView: View {
    let dataStore: PokemonDataStore

    var body: some View {
        NavigationStack {
            CatchCalculatorView(dataStore: dataStore)
        }
    }
}

#Preview {
    let database = try! PokemonDatabase(inMemory: true)
    let repository = PokemonRepository(database: database)
    let store = PokemonDataStore(repository: repository)
    return ContentView(dataStore: store)
}
