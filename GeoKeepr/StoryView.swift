import SwiftUI

struct StoryView: View {
    let recap: WeeklyRecap
    let onDismiss: () -> Void

    @State private var currentSlideIndex = 0
    @State private var progress: Double = 0
    @State private var timer: Timer?
    @State private var isPaused = false

    private let slideDuration: TimeInterval = 4.0

    private var slideCount: Int {
        recap.slides.count
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Content
            GeometryReader { geometry in
                ZStack {
                    if currentSlideIndex < recap.slides.count {
                        switch recap.slides[currentSlideIndex] {
                        case .intro(let start, let end):
                            IntroSlide(startDate: start, endDate: end)
                        case .grind(let work, let personal):
                            GrindSlide(workHours: work, personalHours: personal)
                        case .topSpot(let name, let visits):
                            TopSpotSlide(locationName: name, visits: visits)
                        case .vibe(let vibe):
                            VibeSlide(vibe: vibe)
                        case .deepFocus(let location, let duration):
                            DeepFocusSlide(location: location, duration: duration)
                        case .newHorizons(let locations):
                            NewHorizonsSlide(locations: locations)
                        case .weekendWarrior(let weekend, let weekday):
                            WeekendWarriorSlide(weekendHours: weekend, weekdayHours: weekday)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                // Tap Gestures
                .onTapGesture { location in
                    if location.x < geometry.size.width / 2 {
                        previousSlide()
                    } else {
                        nextSlide()
                    }
                }
                .onLongPressGesture(
                    minimumDuration: 0.2,
                    pressing: { pressing in
                        isPaused = pressing
                    }, perform: {})
            }

            // Progress Bars
            VStack {
                HStack(spacing: 4) {
                    ForEach(0..<slideCount, id: \.self) { index in
                        ProgressBarView(
                            index: index,
                            currentIndex: currentSlideIndex,
                            progress: index == currentSlideIndex
                                ? progress : (index < currentSlideIndex ? 1.0 : 0.0)
                        )
                    }
                }
                .padding(.top, 50)
                .padding(.horizontal)

                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding()
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: isPaused) { paused in
            if paused {
                stopTimer()
            } else {
                startTimer()
            }
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard !isPaused else { return }

            progress += 0.05 / slideDuration
            if progress >= 1.0 {
                nextSlide()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func nextSlide() {
        if currentSlideIndex < slideCount - 1 {
            currentSlideIndex += 1
            progress = 0
        } else {
            onDismiss()
        }
    }

    private func previousSlide() {
        if currentSlideIndex > 0 {
            currentSlideIndex -= 1
            progress = 0
        } else {
            // Restart first slide
            progress = 0
        }
    }
}

struct ProgressBarView: View {
    let index: Int
    let currentIndex: Int
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))

                Capsule()
                    .fill(Color.white)
                    .frame(width: geometry.size.width * CGFloat(progress))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Slides

struct IntroSlide: View {
    let startDate: Date
    let endDate: Date

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Your Week\nin Review")
                .font(.system(size: 40, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)

            Text("\(formatDate(startDate)) - \(formatDate(endDate))")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text("Tap to continue")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 50)
        }
        .background(
            LinearGradient(
                colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct GrindSlide: View {
    let workHours: Double
    let personalHours: Double

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Text("The Grind")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)

            HStack(spacing: 40) {
                VStack {
                    Text("💼")
                        .font(.system(size: 60))
                    Text("Work")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(String(format: "%.1fh", workHours))
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                }

                VStack {
                    Text("🧘")
                        .font(.system(size: 60))
                    Text("Life")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(String(format: "%.1fh", personalHours))
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.blue)
    }
}

struct TopSpotSlide: View {
    let locationName: String
    let visits: Int

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Top Spot")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.yellow)
                .shadow(radius: 10)

            Text(locationName)
                .font(.system(size: 40, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding()

            Text("\(visits) visits")
                .font(.title2)
                .foregroundColor(.white.opacity(0.9))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.orange)
    }
}

struct VibeSlide: View {
    let vibe: WeeklyVibe

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Your Vibe")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)

            Text(vibe.emoji)
                .font(.system(size: 120))
                .shadow(radius: 20)

            Text(vibe.rawValue)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)

            Text(vibe.description)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(vibe.color)
    }
}

struct DeepFocusSlide: View {
    let location: String
    let duration: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Deep Focus")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)

            Image(systemName: "brain.head.profile")
                .font(.system(size: 100))
                .foregroundColor(.cyan)
                .shadow(radius: 10)

            Text("Longest Session")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))

            Text(location)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)

            Text(duration)
                .font(.system(size: 50, weight: .heavy))
                .foregroundColor(.white)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.indigo)
    }
}

struct NewHorizonsSlide: View {
    let locations: [String]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("New Horizons")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)

            Image(systemName: "binoculars.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding(.bottom)

            Text("You explored \(locations.count) new place\(locations.count == 1 ? "" : "s")!")
                .font(.title2)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal)

            VStack(spacing: 10) {
                ForEach(locations.prefix(3), id: \.self) { loc in
                    Text("• \(loc)")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                }
                if locations.count > 3 {
                    Text("and \(locations.count - 3) more...")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.teal)
    }
}

struct WeekendWarriorSlide: View {
    let weekendHours: Double
    let weekdayHours: Double

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Text("Weekend Warrior")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)

            HStack(alignment: .bottom, spacing: 20) {
                VStack {
                    Text(String(format: "%.1fh", weekdayHours))
                        .font(.headline)
                        .foregroundColor(.white)
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 50, height: 100)
                    Text("Week")
                        .font(.caption)
                        .foregroundColor(.white)
                }

                VStack {
                    Text(String(format: "%.1fh", weekendHours))
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 50, height: 180)
                    Text("Weekend")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                }
            }

            Text("You lived it up this weekend!")
                .font(.title3)
                .foregroundColor(.white)
                .padding(.top)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.pink)
    }
}
