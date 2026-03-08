import SwiftUI

/// A view that asynchronously loads and displays a favicon for a given URL.
/// Falls back to the rich CategoryIcon if the load fails or the URL is empty.
struct FaviconView: View {
    let urlString: String
    let category: VaultCategory
    let size: CGFloat

    init(urlString: String, category: VaultCategory, size: CGFloat = 40) {
        self.urlString = urlString
        self.category = category
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
        guard category == .login,
              let domain = domainStr, !domain.isEmpty else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=128")
    }

    var body: some View {
        Group {
            if let faviconUrl = faviconUrl {
                AsyncImage(url: faviconUrl) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            CategoryIcon(category, size: size)
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size, height: size)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: size * 0.2222, style: .continuous))
                    case .failure:
                        CategoryIcon(category, size: size)
                    @unknown default:
                        CategoryIcon(category, size: size)
                    }
                }
            } else {
                CategoryIcon(category, size: size)
            }
        }
        .frame(width: size, height: size)
    }
}
