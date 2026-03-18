# PDF Reader for macOS

A native macOS PDF reader application built with SwiftUI and PDFKit, similar to Apple's Preview app.

## Features

### Core PDF Features
- **PDF Viewing**: Open and view PDF documents with smooth scrolling
- **Page Navigation**: Navigate between pages using toolbar controls or keyboard shortcuts
- **Zoom Controls**: Zoom in/out with buttons or keyboard shortcuts (⌘+, ⌘-)
- **Thumbnail Sidebar**: Visual page thumbnails for quick navigation
- **Search**: Find text within PDF documents (⌘F)
- **Multiple Display Modes**: Single page, continuous, two-up views
- **Drag and Drop**: Drop PDF files directly into the app
- **Continuous Scroll**: Smooth continuous scrolling through pages
- **Full-screen Mode**: Enter full screen with ⌃⌘F
- **Printing Support**: Print documents with ⌘P

### Bookmarks & Annotations
- **Bookmarks**: Add, edit, and manage bookmarks (⌘D)
- **Color-coded bookmarks**: Organize with different colors
- **Annotations**: Highlight, underline, strikethrough text
- **Notes**: Add sticky notes to pages
- **Free text annotations**: Add text anywhere on the page

### Recent Documents
- **Recent Documents List**: Quick access to recently opened files
- **Remember Last Position**: Resume reading from where you left off
- **Document History**: Up to 20 recent documents saved

### AI Assistant
- **Ask AI**: Get answers about your PDF content
- **Multiple Providers**: Support for OpenAI, Anthropic, and Ollama
- **Local LLM Support**: Use local models for privacy
- **Summarize Documents**: Quick document summaries
- **Contextual Answers**: AI uses current page context

### Dictionary & Web Search
- **Dictionary Lookup**: Look up word definitions instantly
- **System Dictionary**: Uses macOS built-in dictionary
- **Online Dictionary**: Falls back to online API
- **Integrated Web Search**: Search selected text on the web
- **Multiple Search Engines**: Google, DuckDuckGo, Bing, Wikipedia, Google Scholar

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘O | Open file |
| ⇧⌘O | Open Recent |
| ⌘P | Print |
| ⌘+ | Zoom in |
| ⌘- | Zoom out |
| ⌘0 | Reset zoom (actual size) |
| ⌘9 | Zoom to fit |
| ⌘F | Find in document |
| ⌘D | Add/Remove bookmark |
| ⌥⌘S | Toggle left sidebar |
| ⌥⌘R | Toggle right panel |
| ⇧⌘A | AI Assistant |
| ⌥⌘D | Dictionary |
| ⇧⌘W | Web Search |
| ⌃⌘F | Full screen |
| ← / → | Previous/Next page |
| ⌘↑ | First page |
| ⌘↓ | Last page |

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

## Building the Project

1. Open `PDFReader.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run (⌘R)

## Project Structure

```
PDFReader/
├── PDFReaderApp.swift           # Main app entry point
├── ContentView.swift            # Main content view with layout
├── DocumentManager.swift        # PDF document state management
├── PDFKitView.swift            # SwiftUI wrapper for PDFView
├── ThumbnailSidebarView.swift  # Page thumbnail sidebar
├── ToolbarView.swift           # Custom toolbar with controls
├── SearchBarView.swift         # Search functionality
├── SettingsView.swift          # App preferences
├── Models/
│   ├── Bookmark.swift          # Bookmark data model
│   ├── RecentDocument.swift    # Recent document model
│   └── AISettings.swift        # AI configuration model
├── Managers/
│   ├── BookmarkManager.swift   # Bookmark persistence
│   ├── RecentDocumentsManager.swift  # Recent docs management
│   ├── AIAssistantManager.swift      # AI API integration
│   └── DictionaryManager.swift       # Dictionary lookup
├── Views/
│   ├── BookmarksView.swift     # Bookmarks sidebar
│   ├── AnnotationsView.swift   # Annotations sidebar
│   ├── RecentDocumentsView.swift     # Recent documents
│   ├── AIAssistantView.swift   # AI chat interface
│   ├── DictionaryView.swift    # Dictionary lookup
│   └── WebSearchView.swift     # Integrated web browser
├── Assets.xcassets/            # App icons and colors
├── Info.plist                  # App configuration
└── PDFReader.entitlements      # App sandbox permissions
```

## AI Setup

### OpenAI
1. Get an API key from https://platform.openai.com
2. Go to Settings > AI
3. Select "OpenAI" as provider
4. Enter your API key

### Anthropic (Claude)
1. Get an API key from https://console.anthropic.com
2. Go to Settings > AI
3. Select "Anthropic" as provider
4. Enter your API key

### Ollama (Local)
1. Install Ollama from https://ollama.ai
2. Run `ollama serve` in terminal
3. Pull a model: `ollama pull llama2`
4. Go to Settings > AI
5. Select "Ollama" as provider

### Features to ADD
1. When closing document if changes are there prompt for saving the file.
2. Toggle to enable Autosave in toolbar.
3. Google Drive Sync.
4. In double page view gap is high between each pages.

### Issue Fixes:
1. Fix issue in the double press next button in two pages view.
2. Highlight option is so convoluted.
    The toolbar still highlight not shows the color correctly.
    Custom color not working.
    When highligting hover option only works then the purpose of highlight option in toolbar not makes sense.
3. Hoverbar AI button should paste the highlighted text in the chat window.

## License

MIT License - Feel free to use and modify as needed.
