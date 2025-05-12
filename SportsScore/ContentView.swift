import SwiftUI

// MARK: - Models

struct Scoreboard: Codable {
    let events: [GameEvent]
}

struct GameEvent: Codable, Identifiable {
    let id: String
    let name: String
    let date: String
    let competitions: [Competition]
}

struct Competition: Codable {
    let competitors: [Team]
    let status: GameStatus
    let venue: Venue
}

struct Venue: Codable {
    let id: String
    let fullName: String
    let address: VenueAddress
    let indoor: Bool?
}

struct VenueAddress: Codable {
    let city: String
    let state: String
    let country: String
}

struct Team: Codable {
    let team: TeamInfo
    let score: String
    let homeAway: String
}

struct TeamInfo: Codable {
    let displayName: String
    let logo: String?
}

struct GameStatus: Codable {
    let type: StatusType
}

struct StatusType: Codable {
    let description: String
}

// MARK: - Data Fetcher

class DataFetcher: ObservableObject {
    @Published var games: [GameEvent] = []
    private var url: URL?

    init(sport: String) {
        // Set the correct URL for sport
        if sport == "nba" {
            self.url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard")
        } else if sport == "nfl" {
            self.url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard")
        } else if sport == "mlb" {
            self.url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard")
        } else if sport == "wnba" {
            self.url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/basketball/wnba/scoreboard")
        } else if sport == "nhl" {
            self.url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard")
        }
    }

    func fetchGames() {
        guard let url = url else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decoded = try JSONDecoder().decode(Scoreboard.self, from: data)
                    DispatchQueue.main.async {
                        self.games = decoded.events
                    }
                } catch {
                    print("Decoding error:", error)
                }
            }
        }.resume()
    }
}

// MARK: - NFL View

struct NFLView: View {
    @StateObject private var fetcher = DataFetcher(sport: "nfl")
    @State private var selectedGame: GameEvent?  // Track the selected game to pass to the details view
    @State private var showDetails = false  // Track if the details sheet should be shown

    var body: some View {
        List(fetcher.games) { event in
            VStack(alignment: .leading, spacing: 10) {
                Text(event.name)
                    .font(.headline)

                Text("Date: \(formattedDate(event.date))")
                    .font(.subheadline)

                HStack {
                    // Left Team (Home)
                    VStack {
                        AsyncImage(url: URL(string: event.competitions.first?.competitors.first?.team.logo ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 50, height: 50)

                        Text(event.competitions.first?.competitors.first?.team.displayName ?? "")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    // Score in the center
                    Text("\(event.competitions.first?.competitors.first?.score ?? "0") - \(event.competitions.first?.competitors.last?.score ?? "0")")
                        .font(.system(size: 48, weight: .bold))
                        .frame(maxWidth: .infinity)

                    // Right Team (Away)
                    VStack {
                        AsyncImage(url: URL(string: event.competitions.first?.competitors.last?.team.logo ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 50, height: 50)

                        Text(event.competitions.first?.competitors.last?.team.displayName ?? "")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)

                Text("Status: \(event.competitions.first?.status.type.description ?? "Unknown")")
                    .font(.footnote)
                    .foregroundColor(.gray)

                // Details Button - Tapping this will show the sheet
                Button("Details") {
                    selectedGame = event
                    showDetails.toggle()  // Toggle the sheet to show the details view
                }
                .font(.footnote)
                .foregroundColor(.blue)
                .padding(.top, 5)
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            fetcher.fetchGames()
        }
        .sheet(item: $selectedGame) { game in
            GameDetailsView(gameEvent: game)
        }
    }

    func formattedDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withTimeZone
        ]
        if let date = formatter.date(from: isoDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "en_US")
            displayFormatter.dateFormat = "MM/dd/yyyy, hh:mm a"
            displayFormatter.timeZone = TimeZone(identifier: "America/New_York")
            return displayFormatter.string(from: date)
        }
        return isoDate
    }
}

struct GameDetailsView: View {
    let gameEvent: GameEvent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text(gameEvent.name)
                    .font(.largeTitle)
                    .bold()

                Text("Date: \(formattedDate(gameEvent.date))")
                    .font(.subheadline)

                ForEach(gameEvent.competitions.first?.competitors ?? [], id: \.team.displayName) { competitor in
                    HStack {
                        if let logo = competitor.team.logo, let url = URL(string: logo) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 50, height: 50)
                        }
                        Text(competitor.team.displayName)
                            .font(.headline)

                        Spacer()

                        Text(competitor.score)
                            .font(.headline)
                    }
                }

                Text("Status: \(gameEvent.competitions.first?.status.type.description ?? "Unknown")")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
            }
            .padding()
        }
        .navigationTitle("Game Details")
    }

    func formattedDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withTimeZone
        ]
        if let date = formatter.date(from: isoDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "en_US")
            displayFormatter.dateFormat = "MM/dd/yyyy, hh:mm a"
            displayFormatter.timeZone = TimeZone(identifier: "America/New_York")
            
            return displayFormatter.string(from: date)
        }
        return isoDate
    }
}

// MARK: - NBA View

struct NBAView: View {
    @StateObject private var fetcher = DataFetcher(sport: "nba")
    @State private var selectedGame: GameEvent?  // Track the selected game to pass to the details view
    @State private var showDetails = false  // Track if the details sheet should be shown


    var body: some View {
        List(fetcher.games) { event in
            VStack(alignment: .leading, spacing: 10) {
                Text(event.name)
                    .font(.headline)

                Text("Date: \(formattedDate(event.date))")
                    .font(.subheadline)

                HStack {
                    // Left Team (Home)
                    VStack {
                        AsyncImage(url: URL(string: event.competitions.first?.competitors.first?.team.logo ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 50, height: 50)

                        Text(event.competitions.first?.competitors.first?.team.displayName ?? "")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)  // Forces the left team to take as much space as needed

                    // Score in the center
                    Text("\(event.competitions.first?.competitors.first?.score ?? "0") - \(event.competitions.first?.competitors.last?.score ?? "0")")
                        .font(.system(size: 48, weight: .bold))  // Big and bold score
                        .frame(maxWidth: .infinity)  // Ensure the score is centered between the two logos

                    // Right Team (Away)
                    VStack {
                        AsyncImage(url: URL(string: event.competitions.first?.competitors.last?.team.logo ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 50, height: 50)

                        Text(event.competitions.first?.competitors.last?.team.displayName ?? "")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)  // Forces the right team to take as much space as needed
                }
                .padding(.vertical, 8)

                Text("Status: \(event.competitions.first?.status.type.description ?? "Unknown")")
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                // Details Button - Tapping this will show the sheet
                Button("Details") {
                    selectedGame = event
                    showDetails.toggle()  // Toggle the sheet to show the details view
                }
                .font(.footnote)
                .foregroundColor(.blue)
                .padding(.top, 5)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("NBA Games")
        .onAppear {
            fetcher.fetchGames()
        }
        .sheet(item: $selectedGame) { game in
            GameDetailsView(gameEvent: game)
        }
    }

    func formattedDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withColonSeparatorInTime]
        
        if let date = formatter.date(from: isoDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "en_US")
            displayFormatter.dateFormat = "MM/dd/yyyy, hh:mm a"
            
            // Set the desired time zone (e.g., U.S. Eastern Time)
            displayFormatter.timeZone = TimeZone(identifier: "America/New_York")
            
            return displayFormatter.string(from: date)
        }
        
        // If parsing fails, return the raw string
        return isoDate
    }
}

// MARK: - MLB View

struct MLBView: View {
    @StateObject private var fetcher = DataFetcher(sport: "mlb")
    @State private var selectedGame: GameEvent?  // Track the selected game to pass to the details view
    @State private var showDetails = false  // Track if the details sheet should be shown


    var body: some View {
        List(fetcher.games) { event in
            VStack(alignment: .leading, spacing: 10) {
                Text(event.name)
                    .font(.headline)

                Text("Date: \(formattedDate(event.date))")
                    .font(.subheadline)

                HStack {
                    // Left Team (Home)
                    VStack {
                        AsyncImage(url: URL(string: event.competitions.first?.competitors.first?.team.logo ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 50, height: 50)

                        Text(event.competitions.first?.competitors.first?.team.displayName ?? "")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)  // Forces the left team to take as much space as needed

                    // Score in the center
                    Text("\(event.competitions.first?.competitors.first?.score ?? "0") - \(event.competitions.first?.competitors.last?.score ?? "0")")
                        .font(.system(size: 48, weight: .bold))  // Big and bold score
                        .frame(maxWidth: .infinity)  // Ensure the score is centered between the two logos

                    // Right Team (Away)
                    VStack {
                        AsyncImage(url: URL(string: event.competitions.first?.competitors.last?.team.logo ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 50, height: 50)

                        Text(event.competitions.first?.competitors.last?.team.displayName ?? "")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)  // Forces the right team to take as much space as needed
                }
                .padding(.vertical, 8)


                Text("Status: \(event.competitions.first?.status.type.description ?? "Unknown")")
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                // Details Button - Tapping this will show the sheet
                Button("Details") {
                    selectedGame = event
                    showDetails.toggle()  // Toggle the sheet to show the details view
                }
                .font(.footnote)
                .foregroundColor(.blue)
                .padding(.top, 5)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("MLB Games")
        .onAppear {
            fetcher.fetchGames()
        }
        .sheet(item: $selectedGame) { game in
            GameDetailsView(gameEvent: game)
        }
    }

    func formattedDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withColonSeparatorInTime]
        
        if let date = formatter.date(from: isoDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "en_US")
            displayFormatter.dateFormat = "MM/dd/yyyy, hh:mm a"
            
            // Set the desired time zone (e.g., U.S. Eastern Time)
            displayFormatter.timeZone = TimeZone(identifier: "America/New_York")
            
            return displayFormatter.string(from: date)
        }
        
        // If parsing fails, return the raw string
        return isoDate
    }
}

// MARK: - WNBA View

struct WNBAView: View {
    @StateObject private var fetcher = DataFetcher(sport: "wnba")
    @State private var selectedGame: GameEvent?  // Track the selected game to pass to the details view
    @State private var showDetails = false  // Track if the details sheet should be shown


    var body: some View {
        List(fetcher.games) { event in
            VStack(alignment: .leading, spacing: 10) {
                Text(event.name)
                    .font(.headline)

                Text("Date: \(formattedDate(event.date))")
                    .font(.subheadline)

                HStack {
                    // Left Team (Home)
                    VStack {
                        AsyncImage(url: URL(string: event.competitions.first?.competitors.first?.team.logo ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 50, height: 50)

                        Text(event.competitions.first?.competitors.first?.team.displayName ?? "")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)  // Forces the left team to take as much space as needed

                    // Score in the center
                    Text("\(event.competitions.first?.competitors.first?.score ?? "0") - \(event.competitions.first?.competitors.last?.score ?? "0")")
                        .font(.system(size: 48, weight: .bold))  // Big and bold score
                        .frame(maxWidth: .infinity)  // Ensure the score is centered between the two logos

                    // Right Team (Away)
                    VStack {
                        AsyncImage(url: URL(string: event.competitions.first?.competitors.last?.team.logo ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 50, height: 50)

                        Text(event.competitions.first?.competitors.last?.team.displayName ?? "")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)  // Forces the right team to take as much space as needed
                }
                .padding(.vertical, 8)


                Text("Status: \(event.competitions.first?.status.type.description ?? "Unknown")")
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                // Details Button - Tapping this will show the sheet
                Button("Details") {
                    selectedGame = event
                    showDetails.toggle()  // Toggle the sheet to show the details view
                }
                .font(.footnote)
                .foregroundColor(.blue)
                .padding(.top, 5)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("WNBA Games")
        .onAppear {
            fetcher.fetchGames()
        }
        .sheet(item: $selectedGame) { game in
            GameDetailsView(gameEvent: game)
        }
    }

    func formattedDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withColonSeparatorInTime]
        
        if let date = formatter.date(from: isoDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "en_US")
            displayFormatter.dateFormat = "MM/dd/yyyy, hh:mm a"
            
            // Set the desired time zone (e.g., U.S. Eastern Time)
            displayFormatter.timeZone = TimeZone(identifier: "America/New_York")
            
            return displayFormatter.string(from: date)
        }
        
        // If parsing fails, return the raw string
        return isoDate
    }
}

// MARK: - NHL View

struct NHLView: View {
    @StateObject private var fetcher = DataFetcher(sport: "nhl")
    @State private var selectedGame: GameEvent?
    @State private var showDetails = false

    var body: some View {
        List(fetcher.games) { event in
            VStack(alignment: .leading, spacing: 10) {
                Text(event.name)
                    .font(.headline)

                Text("Date: \(formattedDate(event.date))")
                    .font(.subheadline)

                HStack {
                    // Left Team (Home)
                    VStack {
                        AsyncImage(url: URL(string: event.competitions.first?.competitors.first?.team.logo ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 50, height: 50)

                        Text(event.competitions.first?.competitors.first?.team.displayName ?? "")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)  // Forces the left team to take as much space as needed

                    // Score in the center
                    Text("\(event.competitions.first?.competitors.first?.score ?? "0") - \(event.competitions.first?.competitors.last?.score ?? "0")")
                        .font(.system(size: 48, weight: .bold))  // Big and bold score
                        .frame(maxWidth: .infinity)  // Ensure the score is centered between the two logos

                    // Right Team (Away)
                    VStack {
                        AsyncImage(url: URL(string: event.competitions.first?.competitors.last?.team.logo ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 50, height: 50)

                        Text(event.competitions.first?.competitors.last?.team.displayName ?? "")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)  // Forces the right team to take as much space as needed
                }
                .padding(.vertical, 8)

                Text("Status: \(event.competitions.first?.status.type.description ?? "Unknown")")
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                // Details Button - Tapping this will show the sheet
                Button("Details") {
                    selectedGame = event
                    showDetails.toggle()  // Toggle the sheet to show the details view
                }
                .font(.footnote)
                .foregroundColor(.blue)
                .padding(.top, 5)
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("NHL Games")
        .onAppear {
            fetcher.fetchGames()
            
        }
        .sheet(item: $selectedGame) { game in
            GameDetailsView(gameEvent: game)
        }
    }

    func formattedDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withColonSeparatorInTime]
        
        if let date = formatter.date(from: isoDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "en_US")
            displayFormatter.dateFormat = "MM/dd/yyyy, hh:mm a"
            
            // Set the desired time zone (e.g., U.S. Eastern Time)
            displayFormatter.timeZone = TimeZone(identifier: "America/New_York")
            
            return displayFormatter.string(from: date)
        }
        
        // If parsing fails, return the raw string
        return isoDate
    }
}

// MARK: - Main Tab View

struct ContentView: View {
    var body: some View {
        TabView {
            NFLView()
                .tabItem {
                    Label("NFL", systemImage: "american.football.fill")
                }
            
            NBAView()
                .tabItem {
                    Label("NBA", systemImage: "basketball.fill")
                }
            
            MLBView()
                .tabItem {
                    Label("MLB", systemImage: "baseball.fill")
                }

            WNBAView()
                .tabItem {
                    Label("WNBA", systemImage: "basketball.fill")
                }

            NHLView()
                .tabItem {
                    Label("NHL", systemImage: "hockey.puck.fill")
                }
        }
    }
}

// MARK: - App Entry Point

@main
struct SportsScoreboardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
