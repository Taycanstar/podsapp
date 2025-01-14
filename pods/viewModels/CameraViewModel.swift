
import SwiftUI
import AVFoundation
import CoreMedia
import MicrosoftCognitiveServicesSpeech
import CommonCrypto
import Combine
import Photos


struct SubscriptionInfo: Codable {
    let status: String
    let plan: String?
    let expiresAt: String?
    let renews: Bool
    let seats: Int?
    let canCreateNewTeam: Bool?
}


struct TeamMembersResponse: Codable {
    let members: [TeamMember]
}

struct TeamMember: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
    let role: String
    let profileInitial: String
    let profileColor: String
}

struct PodMember: Identifiable, Codable {
    let id: Int
    let name: String
    let email: String
    let profileInitial: String
    let profileColor: String
    let role: String
    
}

struct PodDetails: Codable {
    let creator: UserDetails
    let workspace: WorkspaceDetails
}

struct TeamUpdateResponse: Codable {
    let message: String
    let team: TeamData
}

struct TeamData: Codable {
    let id: Int
    let name: String
    let description: String
}


struct TeamDetails: Codable {
    let creator: UserDetails
    let profileInitial: String
    let profileColor: String
    let name: String
    let description: String
    let role: String
}




struct UserDetails: Codable {
    let name: String
    let profileInitial: String
    let profileColor: String
}

struct WorkspaceDetails: Codable {
    let name: String
    let profileInitial: String
    let profileColor: String
}

struct PodInvitation: Identifiable {
    let id: Int
    let podId: Int
    let token: String
    let userName: String
    let userEmail: String
    let podName: String
    let invitationType: String
}

struct TeamInvitation: Identifiable {
    let id: Int
    let teamId: Int
    let token: String
    let userName: String
    let userEmail: String
    let teamName: String
    let invitationType: String
}

struct Team: Identifiable, Codable {
    var id: Int
    var name: String
    var description: String
    var isPersonal: Bool
    var profileInitial: String?
    var profileColor: String?
    var subscriptionId: Int?
    var seatsUsed: Int
    var availableSeats: Int?
    var role: String?
    
    init(id: Int, name: String, description: String, isPersonal: Bool, profileInitial: String?, profileColor: String?, subscriptionId: Int? = nil, seatsUsed: Int = 1, availableSeats: Int? = nil, role: String?) {
        self.id = id
        self.name = name
        self.description = description
        self.isPersonal = isPersonal
        self.profileInitial = profileInitial
        self.profileColor = profileColor
        self.subscriptionId = subscriptionId
        self.seatsUsed = seatsUsed
        self.availableSeats = availableSeats
        self.role = role
    }
}


struct Workspace: Identifiable, Codable {
    var id: Int
    var name: String
    var description: String?
    var coverPhoto: String?
    var icon: String?
    var isMain: Bool
    let profileInitial: String?
    let profileColor: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, coverPhoto, icon, isMain, profileInitial, profileColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        coverPhoto = try container.decodeIfPresent(String.self, forKey: .coverPhoto)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        isMain = try container.decode(Bool.self, forKey: .isMain)
        profileInitial = try container.decodeIfPresent(String.self, forKey: .profileInitial)
        profileColor = try container.decodeIfPresent(String.self, forKey: .profileColor)
    }
}



struct PodColumn: Codable, Identifiable {
    var id: Int            // Real database ID
    var name: String
    var type: String
    var groupingType: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case groupingType = "grouping_type"
    }
}

struct PodItem: Identifiable {
    var id: Int
    var videoURL: URL? {
        didSet {
            if let url = videoURL {
                player = AVPlayer(url: url)
            } else {
                player = nil
            }
        }
    }
    var image: UIImage?
    var metadata: String
    var thumbnail: UIImage?
    var thumbnailURL: URL?
    var imageURL: URL?
    var itemType: String?
    var uuid: String?
    var player: AVPlayer?
    var notes: String
    var columnValues: [String: ColumnValue]? // Single source of truth for user values
}


struct PodItemActivityLog: Identifiable, Comparable {
    let id: Int
    let itemId: Int
    let itemLabel: String
    let userEmail: String
    var loggedAt: Date
    var columnValues: [String: ColumnValue]
    var notes: String
    let userName: String

    init(from json: PodItemActivityLogJSON) throws {
        self.id = json.id
        self.itemId = json.itemId
        self.itemLabel = json.itemLabel
        self.userEmail = json.userEmail
        self.userName = json.userName
        self.notes = json.notes
        self.columnValues = json.columnValues

        let dateFormatters = [
            ISO8601DateFormatter(),
            { () -> ISO8601DateFormatter in
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter
            }()
        ]

        if let date = dateFormatters.lazy.compactMap({ $0.date(from: json.loggedAt) }).first {
            self.loggedAt = date
        } else {
            throw NSError(
                domain: "PodItemActivityLog",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid date format: \(json.loggedAt)"]
            )
        }
    }

    static func < (lhs: PodItemActivityLog, rhs: PodItemActivityLog) -> Bool {
        return lhs.loggedAt > rhs.loggedAt
    }

    static func == (lhs: PodItemActivityLog, rhs: PodItemActivityLog) -> Bool {
        return lhs.id == rhs.id
    }
}

struct PodItemActivityLogJSON: Codable {
    let id: Int
    let itemId: Int
    let itemLabel: String
    let userEmail: String
    let loggedAt: String
    let columnValues: [String: ColumnValue]
    let notes: String
    let userName: String
}


struct ActivityLogResponse: Codable {
    let logs: [PodItemActivityLogJSON]
}


struct Pod: Identifiable {
    var id: Int
    var items: [PodItem] = []
    var title: String
    var templateId: Int?
    var workspace: String?
    var isFavorite: Bool?
    var lastVisited: Date?
    var columns: [PodColumn] = []
    var visibleColumns: [String] = []
    var role: String?
    var description: String?
    var instructions: String?
    var type: String?
    var teamId: Int?
    var recentActivityLogs: [PodItemActivityLog]?

}





struct PodJSON: Codable {
    let id: Int
    let title: String
    let created_at: String
    let items: [PodItemJSON]?
    var templateId: Int?
    let workspace: String?
    var isFavorite: Bool?
    var lastVisited: Date?
    var columns: [PodColumn]
    var visibleColumns: [String]
    var role: String?
    var description: String?
    var instructions: String?
    var type: String?
    var teamId: Int?
    var recentActivityLogs: [PodItemActivityLogJSON]?
  
 
}

struct PodItemJSON: Codable {
    let id: Int
    let videoURL: String?
    let imageURL: String?
    let label: String
    let thumbnail: String?
    let itemType: String?
    let notes: String?
    let columnValues: [String: ColumnValue]
}


enum ColumnValue: Codable, CustomStringConvertible {
    case number(Double)
    case string(String)
    case time(TimeValue)
    case array([ColumnValue])
    case null

    var description: String {
        switch self {
        case .number(let value):
            let roundedNumber = round(value * 10) / 10
            return roundedNumber.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", roundedNumber)
                : String(format: "%.1f", roundedNumber)
        case .string(let value):
            return value
        case .time(let value):
            return value.toString
        case .array(let values):
            return values.map { $0.description }.joined(separator: ", ")
        case .null:
            return ""
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer() 
        if container.decodeNil() {
            self = .null
            return
        }
        
        // Try arrays
        if let arrayValue = try? container.decode([ColumnValue].self) {
            self = .array(arrayValue)
            return
        }
        
        if let arrayValue = try? container.decode([Double].self) {
            self = .array(arrayValue.map { .number($0) })
            return
        }
        
        if let arrayValue = try? container.decode([String].self) {
            self = .array(arrayValue.map { .string($0) })
            return
        }
        
        // Try string first (for time values)
        if let stringValue = try? container.decode(String.self) {
            
            // Attempt to parse the string as JSON array
            if let jsonData = stringValue.data(using: .utf8),
               let jsonArray = try? JSONDecoder().decode([ColumnValue].self, from: jsonData) {
          
                self = .array(jsonArray)
                return
            }
            
            if let timeValue = TimeValue.fromString(stringValue) {
                
                self = .time(timeValue)
                return
            }
       
            self = .string(stringValue)
            return
        }
        
        // Try single numeric values
        if let doubleValue = try? container.decode(Double.self) {
            
            self = .number(doubleValue)
            return
        }
        
        if let intValue = try? container.decode(Int.self) {
        
            self = .number(Double(intValue))
            return
        }

    
        throw DecodingError.typeMismatch(
            ColumnValue.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected String, Double, Int, Array, or null"
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .time(let value):
            try container.encode(value.toString)
        case .array(let values):
            // Encode the array of ColumnValues
            try container.encode(values)
        case .null:
            try container.encodeNil()
        }
    }
}

private struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode([String].self) {
            self.value = value
        } else if let value = try? container.decode([Double].self) {
            self.value = value
        } else if container.decodeNil() {
            self.value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyDecodable value cannot be decoded"
            )
        }
    }
}

//struct Activity: Identifiable, Codable {
//    let id: Int
//    let podId: Int
//    let userEmail: String
//    let duration: Int
//    let loggedAt: Date
//    let notes: String?
//    let userName: String
//    
//    enum CodingKeys: String, CodingKey {
//        case id, podId, userEmail, duration, loggedAt, notes, userName
//    }
//    
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        id = try container.decode(Int.self, forKey: .id)
//        podId = try container.decode(Int.self, forKey: .podId)
//        userEmail = try container.decode(String.self, forKey: .userEmail)
//        duration = try container.decode(Int.self, forKey: .duration)
//        
//        let dateString = try container.decode(String.self, forKey: .loggedAt)
//        let formatter = ISO8601DateFormatter()
//        loggedAt = formatter.date(from: dateString) ?? Date()
//        
//        notes = try container.decodeIfPresent(String.self, forKey: .notes)
//        userName = try container.decode(String.self, forKey: .userName)
//    }
//}
// Models.swift
struct Activity: Identifiable, Codable {
    let id: Int
    let podId: Int
    let userEmail: String
    let userName: String
    let duration: Int
    let loggedAt: Date
    var notes: String?
    let isSingleItem: Bool
    var items: [ActivityItem]
    
    private enum CodingKeys: String, CodingKey {
        case id
        case podId
        case userEmail
        case userName
        case duration
        case loggedAt
        case notes
        case isSingleItem = "is_single_item"
        case items
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        podId = try container.decode(Int.self, forKey: .podId)
        userEmail = try container.decode(String.self, forKey: .userEmail)
        userName = try container.decode(String.self, forKey: .userName)
        duration = try container.decode(Int.self, forKey: .duration)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isSingleItem = try container.decode(Bool.self, forKey: .isSingleItem)
        items = try container.decode([ActivityItem].self, forKey: .items)
        
        let dateString = try container.decode(String.self, forKey: .loggedAt)
        if let date = ISO8601DateFormatter().date(from: dateString) {
            loggedAt = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .loggedAt, in: container, debugDescription: "Date format is invalid")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(podId, forKey: .podId)
        try container.encode(userEmail, forKey: .userEmail)
        try container.encode(userName, forKey: .userName)
        try container.encode(duration, forKey: .duration)
        try container.encode(ISO8601DateFormatter().string(from: loggedAt), forKey: .loggedAt)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(isSingleItem, forKey: .isSingleItem)
        try container.encode(items, forKey: .items)
    }
}

struct ActivityItem: Identifiable, Codable {
    let id: Int
    let activityId: Int
    let itemId: Int
    let itemLabel: String
    let loggedAt: Date
    var notes: String?
    var columnValues: [String: ColumnValue]
    
    private enum CodingKeys: String, CodingKey {
        case id
        case activityId = "activity_id"
        case itemId = "item_id"
        case itemLabel = "item_label"
        case loggedAt = "logged_at"
        case notes
        case columnValues = "column_values"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        activityId = try container.decode(Int.self, forKey: .activityId)
        itemId = try container.decode(Int.self, forKey: .itemId)
        itemLabel = try container.decode(String.self, forKey: .itemLabel)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        columnValues = try container.decode([String: ColumnValue].self, forKey: .columnValues)
        
        let dateString = try container.decode(String.self, forKey: .loggedAt)
        if let date = ISO8601DateFormatter().date(from: dateString) {
            loggedAt = date
        } else {
            throw DecodingError.dataCorruptedError(forKey: .loggedAt, in: container, debugDescription: "Date format is invalid")
        }
    }
}

struct ActivityItemsResponse: Codable {
    let items: [ActivityItem]
    let hasMore: Bool
    let totalPages: Int
    let currentPage: Int
}

struct ActivityResponse: Codable {
    let activities: [Activity]
    let hasMore: Bool
    let totalPages: Int
    let currentPage: Int
}

extension PodItem {
    init(from activityItem: ActivityItem) {
        self.id = activityItem.itemId
        self.metadata = activityItem.itemLabel
        self.notes = activityItem.notes ?? ""
        self.columnValues = activityItem.columnValues
        
        // Set default values for other properties
        self.videoURL = nil
        self.image = nil
        self.thumbnail = nil
        self.thumbnailURL = nil
        self.imageURL = nil
        self.itemType = nil
        self.uuid = nil
        self.player = nil
    }
}

struct TimeValue: Codable, Equatable {
    var hours: Int
    var minutes: Int
    var seconds: Int
    
    var toString: String {
        String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    static func fromString(_ string: String) -> TimeValue? {
        let components = string.split(separator: ":")
        guard components.count == 3,
              let hours = Int(components[0]),
              let minutes = Int(components[1]),
              let seconds = Int(components[2]),
              hours >= 0 && hours <= 23,
              minutes >= 0 && minutes <= 59,
              seconds >= 0 && seconds <= 59
        else {
            return nil
        }
        return TimeValue(hours: hours, minutes: minutes, seconds: seconds)
    }
    
    var totalSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }
    
    static func fromSeconds(_ totalSeconds: Int) -> TimeValue {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return TimeValue(hours: hours, minutes: minutes, seconds: seconds)
    }
}



struct PodResponse: Codable {
    let pods: [PodJSON]

}

extension Pod {
    init(from podJSON: PodJSON) {

        
        self.id = podJSON.id

        
        self.title = podJSON.title

        self.items = podJSON.items?.map { item in

            let mappedItem = PodItem(from: item)

            return mappedItem
        } ?? []
        
        self.templateId = podJSON.templateId
        self.workspace = podJSON.workspace ?? "Main workspace"
        self.isFavorite = podJSON.isFavorite
        self.lastVisited = podJSON.lastVisited
        
    
        self.columns = podJSON.columns

        self.visibleColumns = podJSON.visibleColumns
        self.role = podJSON.role
        self.description = podJSON.description
        self.instructions = podJSON.instructions
        self.type = podJSON.type
        self.teamId = podJSON.teamId

        if let recentActivityLogs = podJSON.recentActivityLogs {
            self.recentActivityLogs = recentActivityLogs.compactMap { logJSON in
                do {
                    return try PodItemActivityLog(from: logJSON)
                } catch {
                    print("Error parsing activity log: \(error)")
                    return nil
                }
            }
        } else {
            self.recentActivityLogs = nil
        }
    }
}


extension PodItem {
    init(from itemJSON: PodItemJSON) {
        self.id = itemJSON.id
        self.itemType = itemJSON.itemType
        
        if let videoURLString = itemJSON.videoURL {
            self.videoURL = URL(string: videoURLString)
        } else {
            self.videoURL = nil
        }
        
        self.metadata = itemJSON.label
        self.thumbnailURL = URL(string: itemJSON.thumbnail ?? "")
        
        if let imageString = itemJSON.imageURL {
            self.imageURL = URL(string: imageString)
        } else {
            self.imageURL = nil
        }
        
        if let url = self.videoURL {
            player = AVPlayer(url: url)
        } else {
            player = nil
        }
        
        self.notes = itemJSON.notes ?? ""
        self.columnValues = itemJSON.columnValues
    }
}



enum CameraMode: String, CaseIterable {
    case fifteen = "15s"
    case thirty = "30s"
    case photo = "Photo"

    var label: String {
        return self.rawValue
    }

    var duration: Double {
        switch self {
        case .fifteen:
            return 15.0
        case .thirty:
            return 30.0
        case .photo:
            return 0.0 // Photo mode might not need a duration, but adjust as needed
        }
    }
}


// MARK: Camera View Model
class CameraViewModel: NSObject,ObservableObject,AVCaptureFileOutputRecordingDelegate, AVCapturePhotoCaptureDelegate{
    

    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCaptureMovieFileOutput()
    @Published var preview : AVCaptureVideoPreviewLayer!
    @Published var isFrontCameraUsed: Bool = false
    @Published var isFlashOn: Bool = false
    var audioRecorder: AVAudioRecorder?
    @Published var isTranscribing: Bool = false
    @Published var isSummarizing: Bool = false
    static let shared = CameraViewModel()
    var savedAudioURL: URL?
    @Published var photoOutput = AVCapturePhotoOutput()
    // Define the selected mode property
    @Published var selectedCameraMode: CameraMode = .fifteen
    @Published var isFlashIntendedForPhoto: Bool = false
    var itemConfirmed: Bool = false
    @Published var currentRecordingUUID: String?
    @Published var isMuted: Bool = true
    var lastConfirmedURL: URL?

    @Published var permissionGranted = false
var hasCheckedPermission = false
    
    


    let voiceCommands = ["start recording", "stop recording"]
    
    private var commandRecognizer: SPXSpeechRecognizer?
    var speechConfig: SPXSpeechConfiguration?
    @Published var selectedImage: UIImage?
    
    
    
    // MARK: Video Recorder Properties
    @Published var isRecording: Bool = false
//    @Published var recordedURLs: [URL] = []
    @Published var previewURL: URL?
    @Published var showPreview: Bool = false
    
    //MARK: Pod variables
    @Published var currentPod = Pod(id: -1,title: "")
    @Published var isPodRecording: Bool = false
    @Published var isPodFinalized = false

    
    // Top Progress Bar
    @Published var recordedDuration: CGFloat = 0
    @Published var maxDuration: CGFloat = 15.0
    @Published var isProcessingVideo = false
    var recordingTimer: Timer?

    
    var isWaveformEnabled = false
    var isSummaryEnabled = false
    var isVcEnabled = false
     var transcription = ""
    
    var speechRecognizer: SPXSpeechRecognizer?
    

    
    @Published var isRecordingAudio = false
    @Published var recordingTimeElapsed = 0.0


    
    // Add zoom properties
    private var initialZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 5.0 // Adjust as needed

    func zoom(factor: CGFloat) {
        print("Attempting to zoom. Current camera: \(isFrontCameraUsed ? "Front" : "Back")")
        print("Initial zoom factor: \(initialZoomFactor)")
        print("Max zoom factor: \(maxZoomFactor)")
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: isFrontCameraUsed ? .front : .back),
              device.activeFormat.videoMaxZoomFactor > 1.0 else {
           
            return
        }
        
        do {
            try device.lockForConfiguration()
            let zoomFactor = initialZoomFactor * factor
            let newZoomFactor = max(1.0, min(zoomFactor, device.activeFormat.videoMaxZoomFactor))
            device.videoZoomFactor = newZoomFactor
            print("Zoom applied. New zoom factor: \(newZoomFactor)")
            device.unlockForConfiguration()
        } catch {
            print("Failed to set zoom factor: \(error)")
        }
    }

    func finalizeZoom(factor: CGFloat) {
        print("Finalizing zoom with factor: \(factor)") // Debug log
        initialZoomFactor = max(1.0, min(initialZoomFactor * factor, maxZoomFactor))
        print("Final zoom factor: \(initialZoomFactor)") // Debug log
    }


    
    func toggleVoiceCommands() {
        self.objectWillChange.send()
        print("Toggling voice commands...")
        print("Current state before toggle: \(isVcEnabled)")
        isVcEnabled.toggle()
        if isVcEnabled {
            print("Voice commands enabled. Starting speech recognition.")
            startSpeechRecognition()
        } else {
            print("Voice commands disabled. Stopping speech recognition.")
            stopSpeechRecognition()
        }
        print("Current state after toggle: \(isVcEnabled)")
    }
    
    func toggleWaveform(){
        if isWaveformEnabled{
            isWaveformEnabled = false
        } else {
            isWaveformEnabled = true
        }
    }
    func toggleSummary(){
        if isSummaryEnabled{
            isSummaryEnabled = false
        } else {
            isSummaryEnabled = true
        }
    }


    func checkPermission() {
          guard !hasCheckedPermission else { return }

          switch AVCaptureDevice.authorizationStatus(for: .video) {
          case .authorized:
              permissionGranted = true
          case .notDetermined:
              AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                  DispatchQueue.main.async {
                      self?.permissionGranted = status
                      if !status {
                          self?.alert = true
                      }
                  }
              }
          case .denied, .restricted:
              alert = true
          @unknown default:
              break
          }
        

          hasCheckedPermission = true
      }
    
    private func getDocumentsDirectory() -> URL {
          FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      }
    
    func setupAudioRecorder() {
           let audioFilename = getDocumentsDirectory().appendingPathComponent("audioRecording.wav")
           let settings = [
               AVFormatIDKey: Int(kAudioFormatLinearPCM),
               AVSampleRateKey: 12000,
               AVNumberOfChannelsKey: 1,
               AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
           ]

           do {
               audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
               audioRecorder?.prepareToRecord()
           } catch {
               print("Audio recorder setup failed: \(error)")
           }
       }



    func setUp() {
        guard permissionGranted else { return }
        do {
            // Set up the audio session for recording
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)

            // Call configureSessionFor with the initial mode
            configureSessionFor(mode: selectedCameraMode)
        } catch {
            print("Error setting up video/audio input or audio session: \(error)")
        }
    }
    
//    func setUp() {
//           // Only configure the session here, not the audio session
//           configureSessionFor(mode: selectedCameraMode)
//       }
    
    // Function to format seconds into minutes:seconds (00:00) format
    func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // Call this method to toggle audio recording
    func toggleRecordingAudio() {
        if isRecordingAudio {
            // Stop recording
            stopAudioRecording()
        } else {
            // Start recording
            startAudioRecording()
        }
        isRecordingAudio.toggle()
    }

    func startAudioRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("newLabel.wav")
        let settings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ] as [String: Any]

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .defaultToSpeaker, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            recordingTimeElapsed = 0 // Reset the timer
        } catch {
            print("Failed to start audio recording: \(error)")
        }
    }

    func stopAudioRecording() {
        audioRecorder?.stop()
        audioRecorder = nil // Optionally reset the recorder
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session after recording: \(error)")
        }
        // Handle the recorded audio file URL
        if let url = audioRecorder?.url {
            print("Recorded audio saved at: \(url)")
        }
    }



    func configureSessionFor(mode: CameraMode) {
        if session.isRunning {
            session.stopRunning()
        }

        session.beginConfiguration()

        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)

        switch mode {
        case .photo:
            configureForPhotoMode()
        case .fifteen, .thirty:
            configureForVideoMode()
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func configureForPhotoMode() {
        // Ensure there's a camera input for the current position
        let currentCameraPosition: AVCaptureDevice.Position = isFrontCameraUsed ? .front : .back
        addCameraInput(position: currentCameraPosition)
        
        if !session.outputs.contains(where: { $0 is AVCapturePhotoOutput }) {
             if session.canAddOutput(photoOutput) {
                 session.addOutput(photoOutput)
                 photoOutput.isHighResolutionCaptureEnabled = true // Enable high-resolution capture
             }
         }
    }



    
    private func configureForVideoMode() {
        // Determine the correct camera position
        let position: AVCaptureDevice.Position = isFrontCameraUsed ? .front : .back
        
        // Add camera and audio inputs
        addCameraInput(position: position) // Use the dynamically determined position
        addAudioInput()
        
        // Add video output
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        // No additional settings are directly applied here for maxDuration
        // maxDuration is used in the recording logic instead
    }

    
    private func addCameraInput(position: AVCaptureDevice.Position) {
        guard let cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let videoInput = try? AVCaptureDeviceInput(device: cameraDevice) else {
            print("Error setting up camera input.")
            return
        }

        let existingVideoInputs = session.inputs.filter { input in
            guard let input = input as? AVCaptureDeviceInput else { return false }
            return input.device.hasMediaType(.video)
        }
        existingVideoInputs.forEach(session.removeInput)

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
            initialZoomFactor = cameraDevice.videoZoomFactor
            maxZoomFactor = cameraDevice.activeFormat.videoMaxZoomFactor // Set the max zoom factor for the current device
            print("Initial zoom factor set: \(initialZoomFactor), Max zoom factor: \(maxZoomFactor)") // Debug log
        } else {
            print("Cannot add video input.")
        }
    }


    private func addAudioInput() {
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
              session.canAddInput(audioInput) else {
            print("Error setting up audio input.")
            return
        }
        session.addInput(audioInput)
    }


    
    func startRecordingBasedOnMode() {
      
        
        switch selectedCameraMode {
        case .fifteen, .thirty:
            startVideoRecording()
        case .photo:
            takePhoto() // Handle photo taking
        }
    }

    func startVideoRecording() {
        guard !isRecording else { return }

        // Consider removing session stop and start logic if not needed every time
        // Ensure the session is correctly configured before starting a new recording
        
        setupAudioRecorder()
        audioRecorder?.record()

        let outputPath = NSTemporaryDirectory() + UUID().uuidString + ".mov"
        let outputFileURL = URL(fileURLWithPath: outputPath)

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.output.connection(with: .video) != nil else {
                print("Failed to start video recording: No active video connection.")
                return
            }

            self.output.startRecording(to: outputFileURL, recordingDelegate: self)
            self.isRecording = true
        }
        
        recordedDuration = 0

         // Start or restart the timer
         recordingTimer?.invalidate() // Invalidate any existing timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
             guard let self = self else { return }
            self.recordedDuration += 0.1
             if self.recordedDuration >= maxDuration {
                 self.stopRecording()
                 timer.invalidate() // Stop the timer
             }
         }
    }


//    
//    func takePhoto() {
//        if !session.isRunning {
//            session.startRunning()
//        }
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Delay for 0.5 seconds
//            guard let connection = self.photoOutput.connection(with: .video), connection.isActive else {
//                print("No active video connection for photo capture.")
//                return
//            }
//
//            if self.isFrontCameraUsed {
//                connection.isVideoMirrored = true
//                connection.videoOrientation = .portrait
//            }
//
//            let photoSettings = AVCapturePhotoSettings()
//            photoSettings.isHighResolutionPhotoEnabled = true
//
//            if self.isFlashIntendedForPhoto {
//                photoSettings.flashMode = .on
//            } else {
//                photoSettings.flashMode = .off
//            }
//
//            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
//        }
//    }
    
    func takePhoto() {
        if !session.isRunning {
            session.startRunning()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Delay for 0.5 seconds
            guard let connection = self.photoOutput.connection(with: .video), connection.isActive else {
                print("No active video connection for photo capture.")
                return
            }

            if self.isFrontCameraUsed {
                connection.isVideoMirrored = true
                connection.videoOrientation = .portrait
            }

            let photoSettings = AVCapturePhotoSettings()
            photoSettings.isHighResolutionPhotoEnabled = true

            if self.isFlashIntendedForPhoto {
                photoSettings.flashMode = .on
            } else {
                photoSettings.flashMode = .off
            }

            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(), let capturedImage = UIImage(data: imageData) else {
            print("Failed to convert photo to image.")
            return
        }

        // Handle image processing in a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let imageToDisplay: UIImage
            if self.isFrontCameraUsed {
                if let cgImg = capturedImage.cgImage {
                    imageToDisplay = UIImage(cgImage: cgImg, scale: capturedImage.scale, orientation: .leftMirrored)
                } else {
                    imageToDisplay = capturedImage
                }
            } else {
                imageToDisplay = capturedImage
            }

            // Update UI on the main thread
            DispatchQueue.main.async {
                self.selectedImage = imageToDisplay
                self.showPreview = true
                self.isProcessingVideo = false
                self.previewURL = nil
                print("Captured image set. Size: \(imageToDisplay.size)")
                self.itemConfirmed = false
            }
        }
    }


    func lockExposureAndWhiteBalanceForPhoto() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }

        do {
            try device.lockForConfiguration()
            
            let currentExposureTargetBias = device.exposureTargetBias
            device.setExposureTargetBias(currentExposureTargetBias, completionHandler: nil)
            
            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }
            
            if device.isWhiteBalanceModeSupported(.locked) {
                device.whiteBalanceMode = .locked
            }

            device.unlockForConfiguration()
        } catch {
            print("Unable to lock device for configuration: \(error)")
        }
    }

    
//    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
//        if let error = error {
//            print("Error capturing photo: \(error.localizedDescription)")
//            return
//        }
//
//        guard let imageData = photo.fileDataRepresentation(), let capturedImage = UIImage(data: imageData) else {
//            print("Failed to convert photo to image.")
//            return
//        }
//
//        // If the front camera was used, mirror the image
//        let imageToDisplay: UIImage
//        if isFrontCameraUsed {
//            // Flip the image for the front camera
//            if let cgImg = capturedImage.cgImage {
//                imageToDisplay = UIImage(cgImage: cgImg, scale: capturedImage.scale, orientation: .leftMirrored)
//            } else {
//                imageToDisplay = capturedImage
//            }
//        } else {
//            imageToDisplay = capturedImage
//        }
//
//        // Handle the image (similar to handling selected image from picker)
//        DispatchQueue.main.async {
//            self.selectedImage = imageToDisplay
//            self.showPreview = true // Indicate to show preview
//            self.isProcessingVideo = false // Update processing state if needed
//            self.previewURL = nil
//            print("Captured image set. Size: \(imageToDisplay.size)")
//            self.itemConfirmed = false
//            // Trigger any UI updates to show the captured image
//        }
//    }


    // Speech Service Configuration
        func configureSpeechService() {
            guard let subscriptionKey = ProcessInfo.processInfo.environment["SPEECH_KEY"],
                  let serviceRegion = ProcessInfo.processInfo.environment["SPEECH_REGION"] else {
                print("Environment variables for SPEECH_KEY and SPEECH_REGION are not set.")
                return
            }
            do {
                self.speechConfig = try SPXSpeechConfiguration(subscription: subscriptionKey, region: serviceRegion)
                // Further configuration if needed
            } catch {
                print("Error configuring speech service: \(error)")
            }
        }
        
    
        // Start speech recognition for commands
    // Start speech recognition for commands
    func startSpeechRecognition() {
        guard let config = self.speechConfig else {
            print("Speech configuration not initialized.")
            return
        }
        
        do {
            let audioConfig = SPXAudioConfiguration()
            self.speechRecognizer = try SPXSpeechRecognizer(speechConfiguration: config, audioConfiguration: audioConfig)
            guard let recognizer = self.speechRecognizer else { return }
            
            // Adjusting the closure to match expected signature and safely unwrapping the result text
            recognizer.addRecognizedEventHandler { [weak self] (recognizer: SPXSpeechRecognizer, eventArgs: SPXSpeechRecognitionEventArgs) in
                DispatchQueue.main.async {
                    guard let strongSelf = self, let resultText = eventArgs.result.text, !resultText.isEmpty else { return }
                    strongSelf.handleRecognizedText(resultText)
                }
            }

            try recognizer.startContinuousRecognition()
        } catch {
            print("Failed to start speech recognition: \(error)")
        }
    }

        
        // Stop speech recognition
        func stopSpeechRecognition() {
            do {
                try self.speechRecognizer?.stopContinuousRecognition()
                // Additional cleanup if needed
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                 try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth])
                 try? AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to stop speech recognition: \(error)")
            }
        }

    
    private func handleRecognizedText(_ text: String) {
        let command = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Using a switch statement can prepare the structure for easier extension with new commands
        switch command {
        case let cmd where cmd.contains("start recording"):
            DispatchQueue.main.async {
                if !self.isRecording {
                    self.startRecordingBasedOnMode() // Ensure this starts recording based on the selected mode
                }
            }
        case let cmd where cmd.contains("stop recording"):
            DispatchQueue.main.async {
                if self.isRecording {
                    self.stopRecording()
                }
            }
        case let cmd where cmd.contains("take photo"):
            DispatchQueue.main.async {
                // Ensure this is called only when in Photo mode to prevent it from interrupting video recording
                if !self.isRecording && self.selectedCameraMode == .photo {
                    self.takePhoto()
                }
            }
        default:
            break
        }
    }


    // Helper function to append text to the transcription safely
    private func appendTranscription(_ text: String) {
        DispatchQueue.main.async {
            self.transcription += text + " "
        }
    }


      func stopRecording() {
          output.stopRecording()
          audioRecorder?.stop()
          isRecording = false
          recordedDuration = 0
          recordingTimer?.invalidate() // Stop the timer
          recordingTimer = nil
          itemConfirmed = false
          if isVcEnabled {
              toggleVoiceCommands()
          }
        
          currentRecordingUUID = UUID().uuidString
          print(transcription, "transcription after")
      }


    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.previewURL = outputFileURL
            self.showPreview = true
            // Ensure the session is reconfigured after recording
            self.configureSessionFor(mode: self.selectedCameraMode)
        }
    }
    

    func compressVideo(inputURL: URL, outputURL: URL, handler: @escaping (Bool, URL?) -> Void) {
        let asset = AVURLAsset(url: inputURL, options: nil)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            print("Cannot create export session.")
            handler(false, nil)
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        let start = CMTimeMake(value: 0, timescale: 600)
        let range = CMTimeRangeMake(start: start, duration: asset.duration)
        exportSession.timeRange = range

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    print("Video compression succeeded.")
                    handler(true, outputURL)
                case .failed:
                    print("Video compression failed: \(String(describing: exportSession.error))")
                    handler(false, nil)
                case .cancelled:
                    print("Video compression cancelled.")
                    handler(false, nil)
                default:
                    print("Unknown error during video compression")
                    handler(false, nil)
                }
            }
        }
    }

    

       func reRecordVideo() {
           previewURL = nil
           showPreview = false
           

           if currentPod.items.isEmpty {
               isPodRecording = false
           }
       }

    func finalizePod() {
            isPodFinalized = true
        }
    
    func toggleFlashForPhotoMode() {
           isFlashIntendedForPhoto.toggle()
       }

  
    func toggleFlash() {
        guard !isFrontCameraUsed, // Add this check
              let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), // Force back camera
              device.hasTorch else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            device.torchMode = device.torchMode == .on ? .off : .on
            isFlashOn = device.torchMode == .on
            
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used: \(error)")
        }
    }

    
    func switchCamera() {
        guard let currentCameraInput = session.inputs.first(where: { input in
            guard let input = input as? AVCaptureDeviceInput else { return false }
            return input.device.hasMediaType(.video)
        }) as? AVCaptureDeviceInput else {
            print("Failed to get current camera input")
            return
        }

        session.beginConfiguration()
        session.removeInput(currentCameraInput)

        let newCameraPosition: AVCaptureDevice.Position = currentCameraInput.device.position == .front ? .back : .front
        guard let newCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newCameraPosition),
              let newCameraInput = try? AVCaptureDeviceInput(device: newCameraDevice) else {
            print("Failed to create new camera input")
            session.commitConfiguration()
            return
        }

        if session.canAddInput(newCameraInput) {
            session.addInput(newCameraInput)
            isFrontCameraUsed.toggle()
            initialZoomFactor = newCameraDevice.videoZoomFactor // Initialize zoom factor for the new device
            maxZoomFactor = newCameraDevice.activeFormat.videoMaxZoomFactor // Set max zoom factor for new device
            print("Switched to \(newCameraPosition == .front ? "front" : "back") camera. Max zoom factor: \(maxZoomFactor)") // Log max zoom factor
        } else {
            print("Cannot add new camera input")
        }

        if let photoConnection = photoOutput.connection(with: .video) {
            if photoConnection.isVideoOrientationSupported {
                photoConnection.videoOrientation = .portrait
            }
        }

        session.commitConfiguration()

        if !session.isRunning {
            session.startRunning()
        }
    }




    private func reconfigureAudioInput() {
        if let currentAudioInput = session.inputs.first(where: { $0 is AVCaptureDeviceInput && ($0 as! AVCaptureDeviceInput).device.hasMediaType(.audio) }) {
            session.removeInput(currentAudioInput)
        }

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }
    }

    
    func reRecordCurrentItem() {
            // Set the preview URL to the last confirmed item if available
            if let lastConfirmed = lastConfirmedURL {
                previewURL = lastConfirmed
            } else {
                previewURL = nil
            }

            // Indicate that we are not currently recording
            isRecording = false

            recordedDuration = 0
        }
    
    func filterCommands(from transcription: String) -> String {
        let commandsToFilter = ["stop recording"] // Add any other commands you want to filter out
        var filteredTranscription = transcription
        for command in commandsToFilter {
            filteredTranscription = filteredTranscription.replacingOccurrences(of: command, with: "")
        }
        return filteredTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
    }


    func transcribeAudioUsingBackend(from url: URL, completion: @escaping (String?) -> Void) {
        NetworkManager().transcribeAudio(from: url) { success, transcription in
        
                if success, let text = transcription {
                    completion(text)
                    print("Transcription successful: \(text)")
                } else {
                    completion(nil)
                    print("Transcription failed.")
                }
          
            
        }
    }
    
    func summarizeVideoUsingBackend(from url: URL, completion: @escaping (String?) -> Void) {
        NetworkManager().summarizeVideo(from: url) { success, transcription in
        
                if success, let text = transcription {
                    completion(text)
                    print("Transcription successful: \(text)")
                } else {
                    completion(nil)
                    print("Transcription failed.")
                }
          
            
        }
    }


// old confirm
//    func confirmVideo() {
//        print(isWaveformEnabled, "is waveform enabled?")
//        
//        guard let videoURL = previewURL, let recordingUUID = currentRecordingUUID else {
//            print("No video to confirm or UUID is missing.")
//            return
//        }
//        resetPreviewState()
//        
//        let isDuplicate = currentPod.items.contains { item in
//            return item.uuid == recordingUUID
//        }
//
//        if isDuplicate {
//            print("Duplicate video detected. Skipping addition.")
//            DispatchQueue.main.async {
//                self.showPreview = false
//            }
//            return
//        }
//
//        let nextId = currentPod.items.count + 1
////        let defaultMetadata = "Item \(nextId)"
//        let defaultMetadata = ""
//        
//        // Use the original video URL directly
//        if self.isWaveformEnabled {
//            print("Waveform enabled, proceeding with transcription.")
//            
//            DispatchQueue.main.async {
//                        self.isTranscribing = true
//                    }
//            self.transcribeAudioUsingBackend(from: videoURL) { transcribedText in
//                DispatchQueue.main.async {
//                    let metadata = transcribedText?.replacingOccurrences(of: "stop recording", with: "", options: .caseInsensitive) ?? defaultMetadata
//                    print("Completing video confirmation with metadata: \(metadata)")
//                    self.completeVideoConfirmation(with: videoURL, metadata: metadata)
//                    self.itemConfirmed = true
//                    if self.isWaveformEnabled {
//                        self.isWaveformEnabled = false
//                    }
//                }
//            }
//        } else {
//            print("Waveform not enabled, skipping transcription.")
//            self.completeVideoConfirmation(with: videoURL, metadata: defaultMetadata)
//            self.itemConfirmed = true
//            if self.isWaveformEnabled {
//                self.isWaveformEnabled = false
//            }
//        }
//    }
//end

    func confirmVideo() {
        print(isSummaryEnabled, "is summary enabled?")
        
        guard let videoURL = previewURL, let recordingUUID = currentRecordingUUID else {
            print("No video to confirm or UUID is missing.")
            return
        }
        resetPreviewState()
        
        let isDuplicate = currentPod.items.contains { item in
            return item.uuid == recordingUUID
        }

        if isDuplicate {
            print("Duplicate video detected. Skipping addition.")
            DispatchQueue.main.async {
                self.showPreview = false
            }
            return
        }

        let nextId = currentPod.items.count + 1
//        let defaultMetadata = "Item \(nextId)"
        let defaultMetadata = ""
        let defaultNotes = ""
        
        // Use the original video URL directly
        if self.isSummaryEnabled {
            print("Summary enabled, proceeding with summarization.")
            
            DispatchQueue.main.async {
                        self.isSummarizing = true
                    }
            self.summarizeVideoUsingBackend(from: videoURL) { transcribedText in
                DispatchQueue.main.async {
                    let notes = transcribedText ?? defaultNotes
                    print("Completing video confirmation with notes: \(notes)")
                    self.completeVideoConfirmation(with: videoURL, metadata: defaultMetadata, notes: notes)
                    self.itemConfirmed = true
                    if self.isSummaryEnabled {
                        self.isSummaryEnabled = false
                    }
                }
            }
        } else {
            print("Waveform not enabled, skipping transcription.")
            self.completeVideoConfirmation(with: videoURL, metadata: defaultMetadata, notes: defaultNotes)
            self.itemConfirmed = true
            if self.isSummaryEnabled {
                self.isSummaryEnabled = false
            }
        }
    }


    func resetPreviewState() {
        // Update UI immediately to indicate that processing has started
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showPreview = false
            self.recordedDuration = 0
            self.isRecording = false
            
        }
    }
    

    func compressVideo(inputURL: URL, outputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let urlAsset = AVURLAsset(url: inputURL, options: nil)
        guard let exportSession = AVAssetExportSession(asset: urlAsset, presetName: AVAssetExportPreset640x480) else {
            completion(.failure(NSError(domain: "VideoCompressionError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    guard let outputURL = exportSession.outputURL else {
                        completion(.failure(NSError(domain: "VideoCompressionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Output URL not found"])))
                        return
                    }
                    completion(.success(outputURL))
                case .failed:
                    completion(.failure(exportSession.error ?? NSError(domain: "VideoCompressionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred during export"])))
                default:
                    completion(.failure(NSError(domain: "VideoCompressionError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Export session completed with unknown status"])))
                }
            }
        }
    }
    

    
    private func completeVideoConfirmation(with videoURL: URL, metadata: String, notes: String) {
        guard let recordingUUID = currentRecordingUUID else {
            print("No video to confirm or UUID is missing.")
            return
        }
        // Check if the last item in the Pod is the same as the current preview URL
        if currentPod.items.last?.videoURL != videoURL {
            let thumbnail = generateThumbnail(for: videoURL, usingFrontCamera: isFrontCameraUsed)
            let newItem = PodItem(id: currentPod.items.count + 1, videoURL: videoURL, metadata: metadata, thumbnail: thumbnail, itemType: "video", uuid: recordingUUID, notes: notes)
            print(newItem, "new item")
            DispatchQueue.main.async {
                self.currentPod.items.append(newItem)
                print("Item confirmed and added to Pod. Current Pod count: \(self.currentPod.items.count), Item Type: \(self.currentPod.items.last?.itemType ?? "nil")")
                // Store the confirmed URL
                self.lastConfirmedURL = videoURL
            }
        } else {
            print("The item is already in the Pod.")
        }
    }

    func confirmPhoto(notes: String = "") {
        guard let selectedImage = selectedImage else {
            print("No photo to confirm.")
            return
        }
        let nextId = currentPod.items.count + 1

        // Check for duplicate image
        if let lastItem = currentPod.items.last,
           let lastImage = lastItem.image,
           lastImage === selectedImage {
            print("Duplicate image detected. Skipping addition.")
            DispatchQueue.main.async {
                self.showPreview = false // Adjust as needed for consistent UI flow
            }
        } else {
            // No duplicate detected, proceed to append the new item
            let newItem = PodItem(id: nextId, videoURL: nil, image: selectedImage, metadata: "", thumbnail: selectedImage, thumbnailURL: nil, itemType: "image", notes: notes)

            DispatchQueue.main.async {
                self.currentPod.items.append(newItem)
                // Consider when and how `selectedImage` should be reset
                // self.selectedImage might be reset here or elsewhere depending on your app's flow
                self.showPreview = false // Adjust as needed for consistent UI flow
                self.itemConfirmed = true
            }
        }
    }


    

    
    func confirmPhoto() {
        guard let selectedImage = selectedImage else {
            print("No photo to confirm.")
            return
        }
        let nextId = currentPod.items.count + 1

        // Check for duplicate image
        if let lastItem = currentPod.items.last,
           let lastImage = lastItem.image,
           lastImage === selectedImage {
            print("Duplicate image detected. Skipping addition.")
            DispatchQueue.main.async {
               
                self.showPreview = false // Adjust as needed for consistent UI flow
            }
        } else {
            // No duplicate detected, proceed to append the new item
            let newItem = PodItem(id: nextId, videoURL: nil, image: selectedImage, metadata: "", thumbnail: selectedImage, thumbnailURL: nil, itemType: "image", notes: "")

            DispatchQueue.main.async {
                self.currentPod.items.append(newItem)
                // Consider when and how `selectedImage` should be reset
                // self.selectedImage might be reset here or elsewhere depending on your app's flow
                self.showPreview = false // Adjust as needed for consistent UI flow
                self.itemConfirmed = true
            }
        }

    }
    
    

    func generateThumbnail(for url: URL, usingFrontCamera: Bool) -> UIImage? {
        let asset = AVAsset(url: url)
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        let time = CMTimeMakeWithSeconds(1.0, preferredTimescale: 600)
        
        do {
            let img = try assetImgGenerate.copyCGImage(at: time, actualTime: nil)
            var thumbnail = UIImage(cgImage: img)
            
            // Flip the thumbnail if it was taken with the front camera
            if usingFrontCamera {
                if let cgImage = thumbnail.cgImage {
                    thumbnail = UIImage(cgImage: cgImage, scale: thumbnail.scale, orientation: .upMirrored)
                }
            }

            return thumbnail
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }

    func confirmVideoAndNavigateToCreatePod() {
//        self.showCreatePodView = true
//            confirmVideo()
        DispatchQueue.global(qos: .background).async {
                self.confirmVideo()
            }
            
        }
    
 

    
    func confirmPhotoAndNavigateToCreatePod() {
//        self.showCreatePodView = true
//            confirmPhoto()
        DispatchQueue.global(qos: .background).async {
                self.confirmPhoto()
            }
           
        }

    func transcribeAudio(from url: URL, completion: @escaping (String?) -> Void) {
        guard let speechConfig = self.speechConfig else {
            print("Speech configuration not set up.")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        guard let audioConfig = SPXAudioConfiguration(wavFileInput: url.path) else {
            print("Audio configuration could not be created.")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        do {
            let speechRecognizer = try SPXSpeechRecognizer(speechConfiguration: speechConfig, audioConfiguration: audioConfig)
            try speechRecognizer.recognizeOnceAsync { result in
                DispatchQueue.main.async {
                    if let text = result.text, !text.isEmpty {
                        completion(text)
                    } else {
                        print("Transcription failed or was empty.")
                        completion(nil)
                    }
                }
            }
        } catch {
            print("Error setting up speech recognizer: \(error)")
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }

    
//    func handleSelectedVideo(_ url: URL) {
//        print("Selected video URL: \(url)")
//
//        // Immediately proceed without extracting audio
//        DispatchQueue.main.async {
//            // Assuming the rest of the processing does not depend on the audio extraction outcome,
//            // you can directly set the preview and show it.
//            self.previewURL = url
//            self.showPreview = true
//            self.isProcessingVideo = false
//            self.itemConfirmed = false
//            self.currentRecordingUUID = UUID().uuidString
//        }
//    }
//
    func handleSelectedVideo(_ url: URL) {
        print("Selected video URL: \(url)")

        // Immediately proceed without extracting audio
        DispatchQueue.main.async {
            // Assuming the rest of the processing does not depend on the audio extraction outcome,
            // you can directly set the preview and show it.
            self.previewURL = url
            self.showPreview = true
            self.isProcessingVideo = false
            self.itemConfirmed = false
            self.currentRecordingUUID = UUID().uuidString
            
            // Check if summary is enabled
            if self.isSummaryEnabled {
                print("Summary enabled, proceeding with summarization.")
                
                self.summarizeVideoUsingBackend(from: url) { transcribedText in
                    DispatchQueue.main.async {
                        let notes = transcribedText ?? ""
                        print("Completing video confirmation with notes: \(notes)")
                        self.completeVideoConfirmation(with: url, metadata: "", notes: notes)
                        self.itemConfirmed = true
                        if self.isSummaryEnabled {
                            self.isSummaryEnabled = false
                        }
                    }
                }
            } else {
                print("Waveform not enabled, skipping transcription.")
                self.completeVideoConfirmation(with: url, metadata: "", notes: "")
                self.itemConfirmed = true
                if self.isSummaryEnabled {
                    self.isSummaryEnabled = false
                }
            }
        }
    }

    
    func handleSelectedImage(_ image: UIImage) {
        DispatchQueue.main.async {
            self.selectedImage = image
            print("Selected image set in CameraViewModel. Size: \(image.size)")
            self.showPreview = true // Triggering preview
            self.isProcessingVideo = false
            self.previewURL = nil
            self.itemConfirmed = false
            self.currentRecordingUUID = UUID().uuidString
        }
    }
    

    func extractAudioFromVideo(videoURL: URL, completion: @escaping (Bool) -> Void) {
        let asset = AVAsset(url: videoURL)
        guard let assetTrack = asset.tracks(withMediaType: .audio).first else {
            print("No audio track found in the video file.")
            completion(false)
            return
        }

        let audioFilename = getDocumentsDirectory().appendingPathComponent("audioRecording.wav")
        do {
            if FileManager.default.fileExists(atPath: audioFilename.path) {
                try FileManager.default.removeItem(at: audioFilename)
            }
        } catch {
            print("Error deleting existing audio file: \(error)")
            completion(false)
            return
        }

        guard let assetReader = try? AVAssetReader(asset: asset),
              let assetWriter = try? AVAssetWriter(url: audioFilename, fileType: .wav) else {
            print("Could not create asset reader/writer.")
            completion(false)
            return
        }

        let readerOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let writerOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let assetReaderOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: readerOutputSettings)
        let assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerOutputSettings)

        if assetReader.canAdd(assetReaderOutput) {
            assetReader.add(assetReaderOutput)
        } else {
            print("Cannot add reader output.")
            completion(false)
            return
        }

        if assetWriter.canAdd(assetWriterInput) {
            assetWriter.add(assetWriterInput)
        } else {
            print("Cannot add writer input.")
            completion(false)
            return
        }

        assetReader.startReading()
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)

        let processingQueue = DispatchQueue(label: "audioProcessingQueue")
        assetWriterInput.requestMediaDataWhenReady(on: processingQueue) {
            while assetWriterInput.isReadyForMoreMediaData {
                if let sampleBuffer = assetReaderOutput.copyNextSampleBuffer() {
                    assetWriterInput.append(sampleBuffer)
                } else {
                    assetWriterInput.markAsFinished()
                    assetWriter.finishWriting {
                        if assetWriter.status == .completed {
                            completion(true)
                        } else {
                            print("Failed to write audio file: \(String(describing: assetWriter.error))")
                            completion(false)
                        }
                    }
                    assetReader.cancelReading()
                    break
                }
            }
        }
    }
    
    func deactivateAudioSession() {
          do {
              let audioSession = AVAudioSession.sharedInstance()
              try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
          } catch {
              print("Error deactivating audio session: \(error)")
          }
      }
    func deactivateSpeechService() {
          speechRecognizer = nil
          speechConfig = nil
      }
    
    func stopAudioRecorder() {
           audioRecorder?.stop()
           audioRecorder = nil
       }
    
    //old start
//    func addVideoItem(podId: Int, email: String, completion: @escaping (Bool, String?) -> Void) {
//        guard let previewURL = previewURL else {
//            completion(false, "No preview URL available.")
//            return
//        }
//
//        let handleCompletion: (String) -> Void = { metadata in
//            let thumbnail = self.generateThumbnail(for: previewURL, usingFrontCamera: self.isFrontCameraUsed)
//            NetworkManager().addNewItem(podId: podId, itemType: "video", videoURL: previewURL, image: nil, label: metadata, thumbnail: thumbnail, email: email) { success, message in
//                if success {
//                    print("Video item added to pod successfully.")
//                } else {
//                    print("Failed to add video item to pod: \(message ?? "Unknown error")")
//                }
//                completion(success, message)
//            }
//        }
//
//        if self.isWaveformEnabled {
//            print("Waveform enabled, proceeding with transcription.")
//            self.isTranscribing = true
//
//            self.transcribeAudioUsingBackend(from: previewURL) { transcribedText in
//                DispatchQueue.main.async {
//                    let metadata = transcribedText?.replacingOccurrences(of: "stop recording", with: "", options: .caseInsensitive) ?? "New item"
//                    print("Completing video addition with metadata: \(metadata)")
//                    handleCompletion(metadata)
//                    if self.isWaveformEnabled {
//                        self.isWaveformEnabled = false
//                    }
//                }
//            }
//        } else {
//            print("Waveform not enabled, skipping transcription.")
//            handleCompletion("New item")
//        }
//    }
//
//
//      func addPhotoItem(podId: Int, email: String, completion: @escaping (Bool, String?) -> Void) {
//          guard let selectedImage = selectedImage else {
//              completion(false, "No image selected.")
//              return
//          }
//
//          let metadata = "New item" // Replace with actual metadata if available
//
//          NetworkManager().addNewItem(podId: podId, itemType: "image", videoURL: nil, image: selectedImage, label: metadata, thumbnail: selectedImage, email: email) { success, message in
//              if success {
//                  print("Photo item added to pod successfully.")
//              } else {
//                  print("Failed to add photo item to pod: \(message ?? "Unknown error")")
//              }
//              completion(success, message)
//          }
//      }
    //end
    
//    func addVideoItem(podId: Int, email: String, completion: @escaping (Bool, String?) -> Void) {
//        guard let previewURL = previewURL else {
//            completion(false, "No preview URL available.")
//            return
//        }
//
//        let handleCompletion: (String) -> Void = { metadata in
//            let thumbnail = self.generateThumbnail(for: previewURL, usingFrontCamera: self.isFrontCameraUsed)
//            NetworkManager().addNewItem(podId: podId, itemType: "video", videoURL: previewURL, image: nil, label: metadata, thumbnail: thumbnail, email: email) { success, message in
//                if success {
//                    print("Video item added to pod successfully.")
//                } else {
//                    print("Failed to add video item to pod: \(message ?? "Unknown error")")
//                }
//                completion(success, message)
//            }
//        }
//
//        if self.isWaveformEnabled {
//            print("Waveform enabled, proceeding with transcription.")
//            self.isTranscribing = true
//
//            self.transcribeAudioUsingBackend(from: previewURL) { transcribedText in
//                DispatchQueue.main.async {
//                    let metadata = transcribedText?.replacingOccurrences(of: "stop recording", with: "", options: .caseInsensitive) ?? "New item"
//                    print("Completing video addition with metadata: \(metadata)")
//                    handleCompletion(metadata)
//                    if self.isWaveformEnabled {
//                        self.isWaveformEnabled = false
//                    }
//                }
//            }
//        } else {
//            print("Waveform not enabled, skipping transcription.")
//            handleCompletion("New item")
//        }
//    }
//
//
//      func addPhotoItem(podId: Int, email: String, completion: @escaping (Bool, String?) -> Void) {
//          guard let selectedImage = selectedImage else {
//              completion(false, "No image selected.")
//              return
//          }
//
//          let metadata = "New item" // Replace with actual metadata if available
//
//          NetworkManager().addNewItem(podId: podId, itemType: "image", videoURL: nil, image: selectedImage, label: metadata, thumbnail: selectedImage, email: email) { success, message in
//              if success {
//                  print("Photo item added to pod successfully.")
//              } else {
//                  print("Failed to add photo item to pod: \(message ?? "Unknown error")")
//              }
//              completion(success, message)
//          }
//      }

    func addVideoItem(podId: Int, email: String, completion: @escaping (Bool, String?) -> Void) {
        guard let previewURL = previewURL else {
            completion(false, "No preview URL available.")
            return
        }

        let handleCompletion: (String, String) -> Void = { metadata, notes in
            let thumbnail = self.generateThumbnail(for: previewURL, usingFrontCamera: self.isFrontCameraUsed)
            NetworkManager().addNewItem(podId: podId, itemType: "video", videoURL: previewURL, image: nil, label: metadata, thumbnail: thumbnail, notes: notes, email: email) { success, message in
                if success {
                    print("Video item added to pod successfully.")
                } else {
                    print("Failed to add video item to pod: \(message ?? "Unknown error")")
                }
                completion(success, message)
            }
        }

        if self.isSummaryEnabled {
            print("Waveform enabled, proceeding with transcription.")
            self.isSummarizing = true

            self.summarizeVideoUsingBackend(from: previewURL) { transcribedText in
                DispatchQueue.main.async {
                    let metadata = "New item"
                    let notes = transcribedText ?? ""
                    print("Completing video addition with metadata: \(metadata)")
                    handleCompletion(metadata, notes)
                    if self.isSummaryEnabled {
                        self.isSummaryEnabled = false
                    }
                }
            }
        } else {
            print("Waveform not enabled, skipping transcription.")
            handleCompletion("New item", "")
        }
    }

    func addPhotoItem(podId: Int, email: String, completion: @escaping (Bool, String?) -> Void) {
        guard let selectedImage = selectedImage else {
            completion(false, "No image selected.")
            return
        }

        let metadata = "New item" // Replace with actual metadata if available
        let notes = ""

        NetworkManager().addNewItem(podId: podId, itemType: "image", videoURL: nil, image: selectedImage, label: metadata, thumbnail: selectedImage, notes: notes, email: email) { success, message in
            if success {
                print("Photo item added to pod successfully.")
            } else {
                print("Failed to add photo item to pod: \(message ?? "Unknown error")")
            }
            completion(success, message)
        }
    }
}





