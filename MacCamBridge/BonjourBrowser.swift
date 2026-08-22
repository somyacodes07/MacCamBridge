import Foundation
import Network
import Combine

struct DiscoveredSender: Identifiable, Hashable {
    let id: String
    let name: String
    let endpoint: NWEndpoint

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DiscoveredSender, rhs: DiscoveredSender) -> Bool {
        lhs.id == rhs.id
    }
}

final class BonjourBrowser: ObservableObject {

    @Published var discoveredSenders: [DiscoveredSender] = []
    @Published var isSearching = false

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.maccambridge.bonjour.browser")

    func startBrowsing() {
        guard browser == nil else { return }

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_maccambridge._tcp", domain: nil)
        let parameters = NWParameters.tcp

        let browser = NWBrowser(for: descriptor, using: parameters)
        self.browser = browser

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            self?.updateResults(results)
        }

        browser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isSearching = true
                case .failed, .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser.start(queue: queue)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        DispatchQueue.main.async {
            self.isSearching = false
            self.discoveredSenders.removeAll()
        }
    }

    private func updateResults(_ results: Set<NWBrowser.Result>) {
        let senders: [DiscoveredSender] = results.compactMap { result in
            switch result.endpoint {
            case .service(let name, _, _, _):
                return DiscoveredSender(id: name, name: name, endpoint: result.endpoint)
            default:
                return nil
            }
        }

        DispatchQueue.main.async {
            self.discoveredSenders = senders
        }
    }
}
