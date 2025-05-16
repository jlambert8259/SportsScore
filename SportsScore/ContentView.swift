import SwiftUI

// MARK: - Data Models

struct Game: Identifiable, Codable {
    let id: String
    let name: String
    let date: String
    let competitions: [Competition]
    let tickets: [Ticket]?
}

struct Competition: Codable {
    let competitors: [Competitor]
    let status: Status
    let venue: Venue?
    let attendance: Int?
    let broadcasts: [Broadcast]?
}

struct Competitor: Codable {
    let team: Team
    let score: String?
    let records: [Record]?
}

struct Team: Codable {
    let displayName: String
    let logo: String
    let abbreviation: String
    let location: String
}

struct Record: Codable {
    let type: String
    let summary: String
}

struct Status: Codable {
    let type: StatusType
    let clock: Double?
    let period: Int?
}

struct StatusType: Codable {
    let description: String
}

struct Venue: Codable {
    let fullName: String
}

struct Broadcast: Codable {
    let names: [String]
}

struct Ticket: Codable, Identifiable {
    var id: String { href }
    let summary: String
    let href: String
}

struct ScoreboardResponse: Codable {
    let events: [Game]
}

// MARK: - Data Fetcher

class DataFetcher: ObservableObject {
    @Published var games: [Game] = []
    private var sportPath: String
    private var timer: Timer?

    init(sportPath: String) {
        self.sportPath = sportPath
        startAutoRefresh()
    }

    func fetchGames() {
        let urlString = "https://site.api.espn.com/apis/site/v2/sports/\(sportPath)/scoreboard"
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data {
                do {
                    let decodedResponse = try JSONDecoder().decode(ScoreboardResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.games = decodedResponse.events
                    }
                } catch {
                    print("Decoding failed: \(error)")
                }
            } else if let error = error {
                print("Network error: \(error)")
            }
        }.resume()
    }

    private func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            self.fetchGames()
        }
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Team View

struct TeamView: View {
    let competitor: Competitor?

    var body: some View {
        VStack {
            if let logoURL = competitor?.team.logo, let url = URL(string: logoURL) {
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 50, height: 50)
            }

            Text(competitor?.team.displayName ?? "")
                .font(.caption)
                .multilineTextAlignment(.center)

            if let record = competitor?.records?.first {
                Text("Record: \(record.summary)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Game Detail View

struct GameDetailView: View {
    let gameID: String
    @ObservedObject var fetcher: DataFetcher

    var currentGame: Game? {
        fetcher.games.first { $0.id == gameID }
    }

    var body: some View {
        ScrollView {
            if let game = currentGame {
                VStack(alignment: .leading, spacing: 12) {
                    Text(game.name)
                        .font(.title2)
                        .padding(.bottom, 5)

                    Text("Date: \(formattedDate(game.date))")
                        .font(.subheadline)

                    if let competition = game.competitions.first {
                        if let venue = competition.venue {
                            Text("Venue: \(venue.fullName)")
                        }

                        if let attendance = competition.attendance {
                            Text("Attendance: \(attendance)")
                        }

                        if let broadcast = competition.broadcasts?.first {
                            Text("Watch on: \(broadcast.names.joined(separator: ", "))")
                        }

                        Text("Status: \(competition.status.type.description)")
                            .font(.footnote)
                            .foregroundColor(.gray)

                        HStack {
                            TeamView(competitor: competition.competitors.first)
                            Text("\(competition.competitors.first?.score ?? "0") - \(competition.competitors.last?.score ?? "0")")
                                .font(.system(size: 28, weight: .bold))
                                .frame(maxWidth: .infinity)
                            TeamView(competitor: competition.competitors.last)
                        }
                        .padding(.vertical, 8)
                    }

                    if let tickets = game.tickets, !tickets.isEmpty {
                        Divider()
                        Text("🎟️ Tickets")
                            .font(.headline)
                        ForEach(tickets) { ticket in
                            Link(destination: URL(string: ticket.href)!) {
                                Text(ticket.summary)
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                        }
                    }
                }
                .padding()
            } else {
                ProgressView("Loading game details...")
                    .padding()
            }
        }
    }

    func formattedDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
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

// MARK: - Sport View

struct SportView: View {
    @StateObject private var fetcher: DataFetcher
    @State private var selectedGame: Game?

    init(sportPath: String) {
        _fetcher = StateObject(wrappedValue: DataFetcher(sportPath: sportPath))
    }

    var body: some View {
        List(fetcher.games) { game in
            VStack(alignment: .leading, spacing: 10) {
                Text(game.name)
                    .font(.headline)

                Text("Date: \(formattedDate(game.date))")
                    .font(.subheadline)

                HStack {
                    TeamView(competitor: game.competitions.first?.competitors.first)
                    Text("\(game.competitions.first?.competitors.first?.score ?? "0") - \(game.competitions.first?.competitors.last?.score ?? "0")")
                        .font(.system(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity)
                    TeamView(competitor: game.competitions.first?.competitors.last)
                }

                Text("Status: \(game.competitions.first?.status.type.description ?? "Unknown")")
                    .font(.footnote)
                    .foregroundColor(.gray)

                Button("Details") {
                    selectedGame = game
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 8)
        }
        .sheet(item: $selectedGame) { game in
            GameDetailView(gameID: game.id, fetcher: fetcher)
        }
        .onAppear {
            fetcher.fetchGames()
        }
    }

    func formattedDate(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
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

// MARK: - Main App View

struct ContentView: View {
    var body: some View {
        TabView {
            SportView(sportPath: "basketball/nba")
                .tabItem {
                    Label("NBA", systemImage: "sportscourt")
                }

            SportView(sportPath: "basketball/wnba")
                .tabItem {
                    Label("WNBA", systemImage: "sportscourt")
                }

            SportView(sportPath: "baseball/mlb")
                .tabItem {
                    Label("MLB", systemImage: "baseball")
                }

            SportView(sportPath: "hockey/nhl")
                .tabItem {
                    Label("NHL", systemImage: "hockey.puck")
                }

            SportView(sportPath: "football/nfl")
                .tabItem {
                    Label("NFL", systemImage: "football")
                }
        }
    }
}

// MARK: - App Entry

@main
struct SportsScoreApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
