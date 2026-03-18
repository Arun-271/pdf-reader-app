//
//  WebSearchView.swift
//  PDFReader
//
//  Integrated web search view
//

import SwiftUI
import WebKit

struct WebSearchView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @State private var searchQuery: String = ""
    @State private var currentURL: URL?
    @State private var isLoading: Bool = false
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var selectedEngine: SearchEngine = .google
    @State private var webViewCoordinator: WebViewCoordinator?
    
    enum SearchEngine: String, CaseIterable {
        case google = "Google"
        case duckduckgo = "DuckDuckGo"
        case bing = "Bing"
        case wikipedia = "Wikipedia"
        case scholar = "Google Scholar"
        
        var searchURL: String {
            switch self {
            case .google: return "https://www.google.com/search?q="
            case .duckduckgo: return "https://duckduckgo.com/?q="
            case .bing: return "https://www.bing.com/search?q="
            case .wikipedia: return "https://en.wikipedia.org/wiki/Special:Search?search="
            case .scholar: return "https://scholar.google.com/scholar?q="
            }
        }
        
        var icon: String {
            switch self {
            case .google: return "g.circle"
            case .duckduckgo: return "shield"
            case .bing: return "b.circle"
            case .wikipedia: return "book.closed"
            case .scholar: return "graduationcap"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 8) {
                HStack {
                    Text("Web Search")
                        .font(.headline)
                    Spacer()
                    
                    Picker("", selection: $selectedEngine) {
                        ForEach(SearchEngine.allCases, id: \.self) { engine in
                            Label(engine.rawValue, systemImage: engine.icon)
                                .tag(engine)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
                
                HStack(spacing: 8) {
                    // Navigation buttons
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canGoBack)
                    
                    Button(action: goForward) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canGoForward)
                    
                    Button(action: reload) {
                        Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search the web...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                performSearch()
                            }
                        
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(6)
                    .background(Color.systemBackground)
                    .cornerRadius(6)
                    
                    Button("Search") {
                        performSearch()
                    }
                    .buttonStyle(.bordered)
                }
                
                // Use selection from PDF
                Button("Search Selected Text from PDF") {
                    useSelection()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(documentManager.pdfView?.currentSelection == nil)
            }
            .padding(12)
            .background(Color.secondarySystemBackground)
            
            Divider()
            
            // Progress bar
            if isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
            }
            
            // Web view
            WebViewContainer(
                url: $currentURL,
                isLoading: $isLoading,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                coordinator: $webViewCoordinator
            )
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
        let urlString = selectedEngine.searchURL + encodedQuery
        if let url = URL(string: urlString) {
            currentURL = url
        }
    }
    
    private func useSelection() {
        if let selection = documentManager.pdfView?.currentSelection,
           let text = selection.string {
            searchQuery = text.trimmingCharacters(in: .whitespacesAndNewlines)
            performSearch()
        }
    }
    
    private func goBack() {
        webViewCoordinator?.webView?.goBack()
    }
    
    private func goForward() {
        webViewCoordinator?.webView?.goForward()
    }
    
    private func reload() {
        if isLoading {
            webViewCoordinator?.webView?.stopLoading()
        } else {
            webViewCoordinator?.webView?.reload()
        }
    }
}

struct WebViewContainer: NSViewRepresentable {
    @Binding var url: URL?
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var coordinator: WebViewCoordinator?
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        context.coordinator.webView = webView
        
        DispatchQueue.main.async {
            coordinator = context.coordinator
        }
        
        // Load initial page
        if let url = url {
            webView.load(URLRequest(url: url))
        } else {
            // Load a blank page or welcome page
            let html = """
            <html>
            <head>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        height: 100vh;
                        margin: 0;
                        background: #f5f5f5;
                        color: #666;
                    }
                    .container { text-align: center; }
                    h2 { color: #333; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h2>🔍 Web Search</h2>
                    <p>Enter a search query above to get started</p>
                </div>
            </body>
            </html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if let url = url, webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
}

class WebViewCoordinator: NSObject, WKNavigationDelegate {
    var parent: WebViewContainer
    var webView: WKWebView?
    
    init(_ parent: WebViewContainer) {
        self.parent = parent
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.parent.isLoading = true
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.parent.isLoading = false
            self.parent.canGoBack = webView.canGoBack
            self.parent.canGoForward = webView.canGoForward
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            self.parent.isLoading = false
        }
    }
}

struct WebSearchView_Previews: PreviewProvider {
    static var previews: some View {
        WebSearchView()
            .environmentObject(DocumentManager())
            .frame(width: 600, height: 500)
    }
}
