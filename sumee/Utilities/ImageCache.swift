import SwiftUI
import Combine

class ImageCache {
    static let shared = NSCache<NSURL, UIImage>()
    
    static func preload(urls: [URL]) {
        for url in urls {
            if shared.object(forKey: url as NSURL) != nil { continue }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data, let image = UIImage(data: data) {
                    shared.setObject(image, forKey: url as NSURL)
                }
            }.resume()
        }
    }
}

class ImageLoader: ObservableObject {
    @Published var phase: AsyncImagePhase = .empty
    
    private var url: URL
    private var cancellable: AnyCancellable?
    
    init(url: URL) {
        self.url = url
    }
    
    deinit {
        cancellable?.cancel()
    }
    
    func setURL(_ newURL: URL) {
        if newURL != self.url {
            self.url = newURL
            self.phase = .empty
            self.cancellable?.cancel()
            load()
        }
    }
    
    func cancel() {
        cancellable?.cancel()
    }
    
    func load() {
        // If already loaded successfully with same URL, don't reload
        if case .success = phase { return }
        
        // Check Memory Cache
        if let cachedImage = ImageCache.shared.object(forKey: url as NSURL) {
            self.phase = .success(Image(uiImage: cachedImage))
            return
        }
        
        // Fetch
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                guard let self = self else { return }
                if let image = image {
                    ImageCache.shared.setObject(image, forKey: self.url as NSURL)
                    self.phase = .success(Image(uiImage: image))
                } else {
                    self.phase = .failure(URLError(.badServerResponse))
                }
            }
    }
    
    func retry() {
        self.phase = .empty
        load()
    }
}

struct CachedAsyncImage<Content: View>: View {
    @StateObject private var loader: ImageLoader
    private let content: (AsyncImagePhase) -> Content
    private let url: URL
    
    init(url: URL, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        _loader = StateObject(wrappedValue: ImageLoader(url: url))
        self.content = content
    }
    
    var body: some View {
        content(loader.phase)
            .onAppear { loader.load() }
            .onDisappear { loader.cancel() }
            .onChange(of: url) { newURL in
                loader.setURL(newURL)
            }
    }
}
