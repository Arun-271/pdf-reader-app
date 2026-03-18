//
//  GoogleDriveManager.swift
//  PDFReader
//
//  Google Drive integration for PDF storage
//

import Foundation
import AppKit

// MARK: - Google Drive File Model
struct GoogleDriveFile: Identifiable, Codable {
    let id: String
    let name: String
    let mimeType: String
    let size: Int64?
    let modifiedDate: Date?
    let webViewLink: String?
    let downloadUrl: String?
    
    var isPDF: Bool {
        mimeType == "application/pdf"
    }
    
    var formattedSize: String {
        guard let size = size else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Authentication State
enum GoogleAuthState {
    case signedOut
    case signingIn
    case signedIn(email: String)
    case error(String)
}

// MARK: - Google Drive Manager
class GoogleDriveManager: ObservableObject {
    static let shared = GoogleDriveManager()
    
    @Published var authState: GoogleAuthState = .signedOut
    @Published var files: [GoogleDriveFile] = []
    @Published var isLoading = false
    @Published var currentFolder: String? = nil
    @Published var folderPath: [String] = []
    
    // OAuth Configuration (to be filled with actual values)
    private let clientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"
    private let redirectURI = "com.pdfreader.app:/oauth2callback"
    private let scopes = ["https://www.googleapis.com/auth/drive.readonly"]
    
    // Token storage
    @Published var accessToken: String? {
        didSet {
            if let token = accessToken {
                UserDefaults.standard.set(token, forKey: "googleDriveAccessToken")
            } else {
                UserDefaults.standard.removeObject(forKey: "googleDriveAccessToken")
            }
        }
    }
    
    @Published var refreshToken: String? {
        didSet {
            if let token = refreshToken {
                UserDefaults.standard.set(token, forKey: "googleDriveRefreshToken")
            } else {
                UserDefaults.standard.removeObject(forKey: "googleDriveRefreshToken")
            }
        }
    }
    
    private init() {
        // Load saved tokens
        accessToken = UserDefaults.standard.string(forKey: "googleDriveAccessToken")
        refreshToken = UserDefaults.standard.string(forKey: "googleDriveRefreshToken")
        
        // Check if we have a valid session
        if accessToken != nil {
            authState = .signedIn(email: "Google User")
            Task {
                await listFiles()
            }
        }
    }
    
    // MARK: - Authentication
    
    func signIn() {
        authState = .signingIn
        
        // Build OAuth URL
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        guard let authURL = components.url else {
            authState = .error("Failed to create auth URL")
            return
        }
        
        // Open in browser
        NSWorkspace.shared.open(authURL)
        
        // Note: In a real implementation, you would:
        // 1. Register a custom URL scheme handler
        // 2. Receive the auth code via callback
        // 3. Exchange it for tokens
        
        // For demo purposes, show instructions
        showAuthInstructions()
    }
    
    func signOut() {
        accessToken = nil
        refreshToken = nil
        files = []
        authState = .signedOut
    }
    
    private func showAuthInstructions() {
        // This would normally be handled by the OAuth callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.authState = .error("Complete sign-in in browser, then enter auth code")
        }
    }
    
    func handleAuthCode(_ code: String) async {
        // Exchange auth code for tokens
        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else { return }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ].map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String {
                
                await MainActor.run {
                    self.accessToken = accessToken
                    self.refreshToken = json["refresh_token"] as? String
                    self.authState = .signedIn(email: "Google User")
                }
                
                await listFiles()
            }
        } catch {
            await MainActor.run {
                self.authState = .error(error.localizedDescription)
            }
        }
    }
    
    // MARK: - File Operations
    
    @MainActor
    func listFiles(inFolder folderId: String? = nil) async {
        guard let token = accessToken else {
            authState = .signedOut
            return
        }
        
        isLoading = true
        
        var query = "mimeType='application/pdf' or mimeType='application/vnd.google-apps.folder'"
        if let folderId = folderId {
            query = "'\(folderId)' in parents and (\(query))"
        } else {
            query = "'root' in parents and (\(query))"
        }
        
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: "files(id,name,mimeType,size,modifiedTime,webViewLink)"),
            URLQueryItem(name: "orderBy", value: "folder,name")
        ]
        
        guard let url = components.url else {
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let filesArray = json["files"] as? [[String: Any]] {
                
                let driveFiles = filesArray.compactMap { fileDict -> GoogleDriveFile? in
                    guard let id = fileDict["id"] as? String,
                          let name = fileDict["name"] as? String,
                          let mimeType = fileDict["mimeType"] as? String else {
                        return nil
                    }
                    
                    let size = fileDict["size"] as? String
                    let modifiedTime = fileDict["modifiedTime"] as? String
                    
                    var modifiedDate: Date? = nil
                    if let timeStr = modifiedTime {
                        let formatter = ISO8601DateFormatter()
                        modifiedDate = formatter.date(from: timeStr)
                    }
                    
                    return GoogleDriveFile(
                        id: id,
                        name: name,
                        mimeType: mimeType,
                        size: size.flatMap { Int64($0) },
                        modifiedDate: modifiedDate,
                        webViewLink: fileDict["webViewLink"] as? String,
                        downloadUrl: nil
                    )
                }
                
                self.files = driveFiles
                self.currentFolder = folderId
            }
        } catch {
            authState = .error(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func downloadFile(_ file: GoogleDriveFile) async -> URL? {
        guard let token = accessToken else { return nil }
        
        let downloadURL = URL(string: "https://www.googleapis.com/drive/v3/files/\(file.id)?alt=media")!
        
        var request = URLRequest(url: downloadURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Save to temporary location
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(file.name)
            
            try data.write(to: fileURL)
            
            return fileURL
        } catch {
            print("Download error: \(error)")
            return nil
        }
    }
    
    func navigateToFolder(_ folderId: String?, folderName: String?) {
        if let name = folderName {
            folderPath.append(name)
        }
        Task {
            await listFiles(inFolder: folderId)
        }
    }
    
    func navigateBack() {
        if !folderPath.isEmpty {
            folderPath.removeLast()
        }
        Task {
            await listFiles(inFolder: folderPath.isEmpty ? nil : currentFolder)
        }
    }
}
