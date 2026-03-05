import SwiftUI

/// A view that asynchronously loads and displays a favicon for a given URL using DuckDuckGo's service.
/// Falls back to a provided category icon if the load fails or the URL is empty.
struct FaviconView: View {
    let urlString: String
    let fallbackIcon: String
    let size: CGFloat

    init(urlString: String, fallbackIcon: String, size: CGFloat = 36) {
        self.urlString = urlString
        self.fallbackIcon = fallbackIcon
        self.size = size
    }

    /// Extracts the base domain from the full URL string
    private var domainStr: String? {
        let lowercased = urlString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowercased.isEmpty else { return nil }

        let stringToParse = lowercased.hasPrefix("http") ? lowercased : "https://\(lowercased)"

        guard let url = URL(string: stringToParse), var host = url.host else {
            return nil
        }

        host = host.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }

    private var faviconUrl: URL? {
        guard let domain = domainStr, !domain.isEmpty else { return nil }
        return URL(string: "https://icons.duckduckgo.com/ip3/\(domain).ico")
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * (8.0 / 36.0), style: .continuous)
                .fill(Color.fpAccentPurple.opacity(0.15))
                .frame(width: size, height: size)

            if let faviconUrl = faviconUrl {
                AsyncImage(url: faviconUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: size, height: size)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size * 0.65, height: size * 0.65)
                            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    case .failure:
                        fallbackIconView
                    @unknown default:
                        fallbackIconView
                    }
                }
            } else {
                fallbackIconView
            }
        }
        .frame(width: size, height: size)
    }

    private var fallbackIconView: some View {
        Image(systemName: fallbackIcon)
            .font(.system(size: size * (15.0 / 36.0)))
            .foregroundColor(.fpAccentPurple)
    }
}
