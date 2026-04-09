import Foundation

// MARK: - Errors

enum StravaUploadError: LocalizedError {
    case notAuthenticated
    case uploadFailed(String)
    case invalidResponse
    case noRouteData

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Strava. Please connect your account first."
        case .uploadFailed(let message):
            return "Strava upload failed: \(message)"
        case .invalidResponse:
            return "Received an invalid response from Strava."
        case .noRouteData:
            return "No route data available for this run."
        }
    }
}

// MARK: - Upload Status

struct UploadStatus {
    let id: Int64
    let status: String
    let activityId: Int64?
}

// MARK: - Service

@MainActor
class StravaUploadService {

    static let shared = StravaUploadService()

    private let baseURL = StravaConfig.baseAPIURL
    private let session = URLSession.shared

    private init() {}

    // MARK: - High-Level Upload

    /// Uploads a run to Strava. If route data exists, uploads GPX (which creates the activity
    /// from the file with full route). Otherwise, creates a manual activity via the API.
    /// Returns the Strava activity ID (or upload ID if GPX — the activity is created async by Strava).
    func uploadRun(run: Run, authService: StravaAuthService) async throws -> Int64 {
        try await authService.refreshTokenIfNeeded()

        guard let accessToken = authService.accessToken else {
            throw StravaUploadError.notAuthenticated
        }

        if run.routePolyline != nil {
            // Upload GPX — Strava creates the activity asynchronously from the file.
            // Poll until processing completes to get the real activity ID.
            // Falls back to manual activity creation if GPX generation fails.
            do {
                let uploadId = try await uploadGPX(run: run, accessToken: accessToken)
                let activityId = try await pollForActivityId(uploadId: uploadId, accessToken: accessToken)
                return activityId
            } catch {
                let activityId = try await createActivity(run: run, accessToken: accessToken)
                return activityId
            }
        } else {
            // No route data — create a manual activity
            let activityId = try await createActivity(run: run, accessToken: accessToken)
            return activityId
        }
    }

    // MARK: - Activity Metadata

    /// Builds the Strava activity name for a run.
    static func activityName(for run: Run) -> String {
        let miles = run.distanceMeters / 1609.344
        let milesFormatted = String(format: "%.1f", miles)
        let butterFormatted = String(format: "%.1f", run.totalButterBurnedTsp)
        return "Butter Run - \(milesFormatted) mi (burned \(butterFormatted) pats)"
    }

    /// Builds the Strava activity description for a run.
    static func activityDescription(for run: Run) -> String {
        let milesFormatted = String(format: "%.1f", run.distanceMeters / 1609.344)
        let butterFormatted = String(format: "%.1f", run.totalButterBurnedTsp)

        var description = "Tracked with Butter Run"
        description += "\nDistance: \(milesFormatted) mi"
        description += "\nButter burned: \(butterFormatted) pats"
        description += "\nCalories: \(String(format: "%.0f", run.totalCaloriesBurned))"
        if run.elevationGainMeters > 0 {
            description += "\nElevation gain: \(String(format: "%.0f", run.elevationGainMeters)) m"
        }
        if let notes = run.notes, !notes.isEmpty {
            description += "\n\n\(String(notes.prefix(500)))"
        }
        return description
    }

    // MARK: - Create Activity

    /// Creates a manual activity on Strava via POST /activities.
    /// Returns the new activity ID.
    func createActivity(run: Run, accessToken: String) async throws -> Int64 {
        guard let url = URL(string: "\(baseURL)/activities") else {
            throw StravaUploadError.invalidResponse
        }

        let name = Self.activityName(for: run)
        let description = Self.activityDescription(for: run)

        // Strava expects start_date_local as local time WITHOUT timezone
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        let startDateLocal = localFormatter.string(from: run.startDate)

        let body: [String: Any] = [
            "name": name,
            "type": "Run",
            "sport_type": "Run",
            "start_date_local": startDateLocal,
            "elapsed_time": Int(run.durationSeconds),
            "distance": run.distanceMeters,
            "description": description
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            let message = String((String(data: data, encoding: .utf8) ?? "Unknown error").prefix(200))
            throw StravaUploadError.uploadFailed(message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let activityIdNumber = json["id"] as? NSNumber
        else {
            throw StravaUploadError.invalidResponse
        }

        return activityIdNumber.int64Value
    }

    // MARK: - Upload GPX

    /// Uploads GPX data for a run via POST /uploads (multipart/form-data).
    /// Returns the upload ID.
    func uploadGPX(run: Run, accessToken: String) async throws -> Int64 {
        guard let url = URL(string: "\(baseURL)/uploads") else {
            throw StravaUploadError.invalidResponse
        }

        let gpxData = try generateGPXData(from: run)

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build activity name and description
        let name = Self.activityName(for: run)
        let butterFormatted = String(format: "%.1f", run.totalButterBurnedTsp)

        var description = "Tracked with Butter Run"
        description += "\nButter burned: \(butterFormatted) pats"
        description += "\nCalories: \(String(format: "%.0f", run.totalCaloriesBurned))"

        var body = Data()

        // Metadata fields
        body.appendMultipartField(name: "data_type", value: "gpx", boundary: boundary)
        body.appendMultipartField(name: "name", value: name, boundary: boundary)
        body.appendMultipartField(name: "description", value: description, boundary: boundary)
        body.appendMultipartField(name: "activity_type", value: "run", boundary: boundary)

        // GPX file
        body.appendMultipartFile(
            name: "file",
            fileName: "butter_run.gpx",
            mimeType: "application/gpx+xml",
            data: gpxData,
            boundary: boundary
        )

        // Closing boundary
        body.append(Data("--\(boundary)--\r\n".utf8))

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            let message = String((String(data: data, encoding: .utf8) ?? "Unknown error").prefix(200))
            throw StravaUploadError.uploadFailed(message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uploadIdNumber = json["id"] as? NSNumber
        else {
            throw StravaUploadError.invalidResponse
        }

        return uploadIdNumber.int64Value
    }

    // MARK: - Check Upload Status

    /// Checks the processing status of a GPX upload via GET /uploads/{uploadId}.
    func checkUploadStatus(uploadId: Int64, accessToken: String) async throws -> UploadStatus {
        guard let url = URL(string: "\(baseURL)/uploads/\(uploadId)") else {
            throw StravaUploadError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            let message = String((String(data: data, encoding: .utf8) ?? "Unknown error").prefix(200))
            throw StravaUploadError.uploadFailed(message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idNumber = json["id"] as? NSNumber,
              let status = json["status"] as? String
        else {
            throw StravaUploadError.invalidResponse
        }

        let activityId = (json["activity_id"] as? NSNumber)?.int64Value

        return UploadStatus(id: idNumber.int64Value, status: status, activityId: activityId)
    }

    // MARK: - Poll Upload Status

    /// Polls Strava's upload endpoint until processing completes, returning the final activity ID.
    /// Strava GPX processing typically takes 2-15 seconds.
    private func pollForActivityId(uploadId: Int64, accessToken: String, maxAttempts: Int = 10) async throws -> Int64 {
        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                // Exponential backoff: 2s, 4s, 4s, 4s...
                let delay = attempt == 1 ? 2 : 4
                try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            }

            let status = try await checkUploadStatus(uploadId: uploadId, accessToken: accessToken)

            if let activityId = status.activityId {
                return activityId
            }

            // If Strava reports an error, stop polling
            if status.status.contains("error") {
                throw StravaUploadError.uploadFailed(status.status)
            }
        }

        // Timed out waiting — return the upload ID as fallback
        // (the activity will still be created, just not tracked precisely)
        return uploadId
    }

    // MARK: - GPX Generation

    /// Generates GPX 1.1 XML data from the run's routePolyline.
    private func generateGPXData(from run: Run) throws -> Data {
        guard let polylineData = run.routePolyline else {
            throw StravaUploadError.noRouteData
        }

        let coordinates = try JSONDecoder().decode([[Double]].self, from: polylineData)

        guard !coordinates.isEmpty else {
            throw StravaUploadError.noRouteData
        }

        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let startTime = run.startDate.timeIntervalSince1970
        let totalDuration = run.durationSeconds
        let pointCount = coordinates.count
        let timeInterval = pointCount > 1 ? totalDuration / Double(pointCount - 1) : 0

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Butter Run"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <trk>
            <name>Butter Run</name>
            <trkseg>

        """

        for (index, coord) in coordinates.enumerated() {
            guard coord.count >= 2 else { continue }
            let lat = coord[0]
            let lng = coord[1]
            guard (-90...90).contains(lat), (-180...180).contains(lng) else { continue }
            let pointTime = Date(timeIntervalSince1970: startTime + timeInterval * Double(index))
            let timeString = iso8601Formatter.string(from: pointTime)

            gpx += "      <trkpt lat=\"\(lat)\" lon=\"\(lng)\">\n"
            gpx += "        <time>\(timeString)</time>\n"
            gpx += "      </trkpt>\n"
        }

        gpx += """
            </trkseg>
          </trk>
        </gpx>

        """

        guard let data = gpx.data(using: .utf8) else {
            throw StravaUploadError.noRouteData
        }

        return data
    }
}

// MARK: - Data Multipart Helpers

private extension Data {

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append(Data("--\(boundary)\r\n".utf8))
        append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        append(Data("\(value)\r\n".utf8))
    }

    mutating func appendMultipartFile(name: String, fileName: String, mimeType: String, data: Data, boundary: String) {
        append(Data("--\(boundary)\r\n".utf8))
        append(Data("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".utf8))
        append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        append(data)
        append(Data("\r\n".utf8))
    }
}
