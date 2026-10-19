import SwiftUI
import UIKit

/// UIKit owns horizontal pan cancellation; vertical pans remain with the library scroll view.
struct SquareSwipeContainer: UIViewControllerRepresentable {
    let surface: AnyView
    let actions: AnyView
    let width: CGFloat
    let actionWidth: CGFloat
    let revealed: Bool
    let enabled: Bool
    let onReveal: (Bool) -> Void
    let onDrag: () -> Void

    func makeUIViewController(context: Context) -> SquareSwipeController { SquareSwipeController() }
    func updateUIViewController(_ controller: SquareSwipeController, context: Context) {
        controller.update(surface: surface, actions: actions, width: width, actionWidth: actionWidth,
                          revealed: revealed, enabled: enabled, onReveal: onReveal, onDrag: onDrag)
    }
}

final class SquareSwipeController: UIViewController, UIScrollViewDelegate {
    private let scroller = DirectionalTileScrollView()
    private let host = UIHostingController(rootView: AnyView(EmptyView()))
    private var actionWidth: CGFloat = 0
    private var onReveal: (Bool) -> Void = { _ in }
    private var onDrag: () -> Void = { }

    override func loadView() {
        view = scroller
        scroller.delegate = self
        scroller.showsHorizontalScrollIndicator = false
        scroller.showsVerticalScrollIndicator = false
        scroller.bounces = false
        scroller.contentInsetAdjustmentBehavior = .never
        addChild(host); scroller.addSubview(host.view); host.didMove(toParent: self)
        host.view.backgroundColor = .clear
        host.safeAreaRegions = []
    }
    func update(surface: AnyView, actions: AnyView, width: CGFloat, actionWidth: CGFloat,
                revealed: Bool, enabled: Bool, onReveal: @escaping (Bool) -> Void, onDrag: @escaping () -> Void) {
        loadViewIfNeeded()
        self.actionWidth = actionWidth; self.onReveal = onReveal; self.onDrag = onDrag
        host.rootView = AnyView(HStack(spacing: 0) {
            surface.frame(width: width, height: width).clipped()
            actions.frame(width: actionWidth, height: width)
        }.frame(width: width + actionWidth, height: width))
        host.view.frame = CGRect(x: 0, y: 0, width: width + actionWidth, height: width)
        scroller.contentSize = CGSize(width: width + actionWidth, height: width)
        scroller.isScrollEnabled = enabled
        if !scroller.isDragging && !scroller.isDecelerating {
            let target = enabled && revealed ? actionWidth : 0
            if abs(scroller.contentOffset.x - target) > 0.5 { scroller.setContentOffset(CGPoint(x: target, y: 0), animated: false) }
        }
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { onDrag() }
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
                                  targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let open = velocity.x > 0.2 || (velocity.x >= -0.2 && targetContentOffset.pointee.x > actionWidth / 2)
        targetContentOffset.pointee = CGPoint(x: open ? actionWidth : 0, y: 0)
        onReveal(open)
    }
}

private final class DirectionalTileScrollView: UIScrollView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            let velocity = panGestureRecognizer.velocity(in: self)
            guard abs(velocity.x) > abs(velocity.y) * 1.5 else { return false }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
    override func touchesShouldCancel(in view: UIView) -> Bool { true }
}
