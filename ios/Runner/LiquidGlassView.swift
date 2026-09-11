import Flutter
import SwiftUI
import UIKit

/// Factory + platform view for one iOS 26 Liquid Glass surface
/// (viewType "liquid_glass"), used behind the header's avatar, eye and bell
/// buttons and the "Данс хайх" pill. Flutter passes
/// `{"shape": "circle" | "capsule", "clear": Bool}`, then draws the
/// icon/label and handles taps on top of this view.
final class LiquidGlassFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let params = args as? [String: Any] ?? [:]
    return LiquidGlassPlatformView(
      frame: frame,
      surface: LiquidGlassSurface(
        capsule: params["shape"] as? String == "capsule",
        clear: params["clear"] as? Bool ?? false
      )
    )
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let host: UIHostingController<LiquidGlassSurface>

  init(frame: CGRect, surface: LiquidGlassSurface) {
    container = UIView(frame: frame)
    container.backgroundColor = .clear
    host = UIHostingController(rootView: surface)
    super.init()
    host.view.frame = container.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    host.view.backgroundColor = .clear
    host.view.isUserInteractionEnabled = false  // Flutter handles taps
    container.addSubview(host.view)
  }

  func view() -> UIView { container }
}

struct LiquidGlassSurface: View {
  let capsule: Bool
  let clear: Bool

  var body: some View {
    if #available(iOS 26.0, *) {
      glass
        .environment(\.colorScheme, .dark)  // the header is dark
        .ignoresSafeArea()
    } else if capsule {
      // Pre-iOS 26: the design's translucent white fill.
      Capsule().fill(Color.white.opacity(0.1))
    } else {
      Circle().fill(Color.white.opacity(0.1))
    }
  }

  @available(iOS 26.0, *)
  @ViewBuilder private var glass: some View {
    let style: Glass = clear ? .clear : .regular
    if capsule {
      Color.clear.glassEffect(style, in: Capsule())
    } else {
      Color.clear.glassEffect(style, in: Circle())
    }
  }
}
