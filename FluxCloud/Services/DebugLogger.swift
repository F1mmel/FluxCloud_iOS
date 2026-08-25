import Foundation

public class DebugLogger: ObservableObject {
    public static let shared = DebugLogger()
    
    @Published public var logs: [String] = []
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }()
    
    public func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        print(line)
        DispatchQueue.main.async {
            self.logs.append(line)
            // Limit log history to 100 entries
            if self.logs.count > 100 {
                self.logs.removeFirst(self.logs.count - 100)
            }
        }
    }
    
    public func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
}
