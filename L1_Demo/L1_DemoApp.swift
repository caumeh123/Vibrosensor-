import SwiftUI
import CoreHaptics

@main
struct VibroSensorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct Recording: Identifiable {
    let id = UUID()
    let timestamp: Date
    let dataPreview: [Double]
}

struct ContentView: View {
    @State private var screen: Screen = .welcome
    @State private var hapticEngine: CHHapticEngine?
    @State private var timer: Timer?
    @State private var sensorData: [Double] = Array(repeating: 0.0, count: 300)
    @State private var phase: Double = 0
    @State private var logs: [Recording] = []

    enum Screen {
        case welcome, menu, connecting, waveform, logs
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.white]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            Image("nature")
                .resizable()
                .ignoresSafeArea()
                .opacity(0.4)

            switch screen {
            case .welcome:
                VStack(spacing: 20) {
                    Image("brainlogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(15)

                    Text("Welcome to the VibroSensor App!")
                        .font(.largeTitle)
                        .foregroundColor(.black)
                        .padding()

                    Button("Begin") {
                        withAnimation { screen = .menu }
                    }
                    .font(.title2)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                }

            case .menu:
                VStack(spacing: 30) {
                    Text("Main Menu")
                        .font(.largeTitle)
                        .foregroundColor(.black)

                    Button("Capture New Recording") {
                        withAnimation { screen = .connecting }
                        triggerHaptic()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                screen = .waveform
                                startGeneratingSensorData()
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("View Old Logs") {
                        withAnimation { screen = .logs }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Export Logs") {
                        exportLogs()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

            case .connecting:
                VStack {
                    Text("Connecting to sensor...")
                        .font(.title)
                        .foregroundColor(.black)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(1.5)
                }

            case .waveform:
                VStack(spacing: 20) {
                    Text("Live Sensor Data")
                        .font(.title)
                        .foregroundColor(.black)

                    WaveformView(dataPoints: sensorData, color: .blue)
                        .frame(height: 100)

                    Button("End & Save Recording") {
                        stopGeneratingSensorData()
                        saveCurrentRecording()
                        withAnimation { screen = .menu }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding()

            case .logs:
                VStack {
                    Text("Previous Recordings")
                        .font(.title)
                        .padding()

                    if logs.isEmpty {
                        Text("No recordings yet.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List(logs) { log in
                            VStack(alignment: .leading) {
                                Text("Recording: \(log.timestamp.formatted(date: .abbreviated, time: .standard))")
                                    .font(.headline)

                                WaveformView(dataPoints: log.dataPreview, color: .green)
                                    .frame(height: 60)
                            }
                        }
                    }

                    Button("Back to Menu") {
                        withAnimation { screen = .menu }
                    }
                    .padding()
                }
            }
        }
        .onAppear { prepareHaptics() }
    }

    func startGeneratingSensorData() {
        timer?.invalidate()
        phase = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            phase += 0.2
            let jitter = (Int(phase) % 100 > 80) ? Double.random(in: -0.5...0.5) : Double.random(in: -0.05...0.05)
            let newPoint = 0.2 * sin(phase) + jitter
            sensorData.append(newPoint)
            sensorData.removeFirst()
        }
    }

    func stopGeneratingSensorData() {
        timer?.invalidate()
    }

    func saveCurrentRecording() {
        let snapshot = Array(sensorData.suffix(300))
        logs.insert(Recording(timestamp: Date(), dataPreview: snapshot), at: 0)
        if logs.count > 5 {
            logs.removeLast()
        }
    }

    func exportLogs() {
        print("Exporting logs... [mocked]")
    }

    func prepareHaptics() {
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine error: \(error.localizedDescription)")
        }
    }

    func triggerHaptic() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Haptic error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    var dataPoints: [Double]
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let step = width / CGFloat(dataPoints.count - 1)
            let midY = height / 2

            Path { path in
                path.move(to: CGPoint(x: 0, y: midY))
                for (index, value) in dataPoints.enumerated() {
                    let x = CGFloat(index) * step
                    let y = midY - CGFloat(value) * (height / 2)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(color, lineWidth: 2)
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: 250)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: 250)
            .background(Color.white.opacity(0.7))
            .foregroundColor(.blue)
            .cornerRadius(10)
    }
}
