import SwiftUI

struct StoryView: View {
    let recap: WeeklyRecap
    let onDismiss: () -> Void

    @State private var currentSlideIndex = 0
    @State private var progress: Double = 0
    @State private var timer: Timer?
    @State private var isPaused = false

    private let slideDuration: TimeInterval = 4.0
    private let slideCount = 4

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Content
            GeometryReader { geometry in
                ZStack {
                    switch currentSlideIndex {
                    case 0: IntroSlide(recap: recap)
                    case 1: GrindSlide(recap: recap)
                    case 2: TopSpotSlide(recap: recap)
                    case 3: VibeSlide(recap: recap)
                    default: EmptyView()
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
    let recap: WeeklyRecap

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Your Week\nin Review")
                .font(.system(size: 40, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)

            Text("\(formatDate(recap.startDate)) - \(formatDate(recap.endDate))")
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
    let recap: WeeklyRecap

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
                    Text(String(format: "%.1fh", recap.workHours))
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
                    Text(String(format: "%.1fh", recap.personalHours))
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
    let recap: WeeklyRecap

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

            Text(recap.topLocationName ?? "Unknown")
                .font(.system(size: 40, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding()

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.orange)
    }
}

struct VibeSlide: View {
    let recap: WeeklyRecap

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Your Vibe")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)

            Text(recap.vibe.emoji)
                .font(.system(size: 120))
                .shadow(radius: 20)

            Text(recap.vibe.rawValue)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)

            Text(recap.vibe.description)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(recap.vibe.color)
    }
}
