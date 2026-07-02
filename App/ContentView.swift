import SwiftUI

/// Routes between the paste screen (no text) and the reading surface, with a soft
/// crossfade + settle between screens instead of a hard swap.
struct ContentView: View {
    let viewModel: ReaderViewModel
    let ideas: IdeasViewModel

    private enum Route: Equatable { case link, resume, paste, review, reading }

    private var route: Route {
        if viewModel.pendingLink != nil { return .link }
        if viewModel.pendingResume != nil && viewModel.state == .idle { return .resume }
        if viewModel.state == .idle { return .paste }
        if viewModel.state == .completed { return .review }
        return .reading
    }

    var body: some View {
        ZStack {
            switch route {
            case .link:
                LinkFallbackView(viewModel: viewModel).transition(screenTransition)
            case .resume:
                if let resume = viewModel.pendingResume {
                    ResumeView(viewModel: viewModel, candidate: resume).transition(screenTransition)
                }
            case .paste:
                PasteView(viewModel: viewModel).transition(screenTransition)
            case .review:
                ReviewView(viewModel: viewModel).transition(screenTransition)
            case .reading:
                ReadingView(viewModel: viewModel, ideas: ideas).transition(screenTransition)
            }
        }
        .animation(.easeOut(duration: 0.25), value: route)
        // Keep the reading screen lit while engaged with the thumb.
        .persistentSystemOverlays(.hidden)
    }

    private var screenTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.98))
    }
}
