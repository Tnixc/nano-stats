import AppKit

/// A lightweight, reusable sparkline view that renders a full-width line graph
/// using system colors that automatically adapt to light/dark appearances.
/// - Features:
///   - Full-width drawing that resizes with its container
///   - System accent color line with adaptive warning colors for high values
///   - Optional gradient fill under the line
///   - Configurable value cap and insets
///   - Simple API: assign `values` or call `appendValue(_:)`
public final class SparklineView: NSView {

  // MARK: - Types

  /// Determines how Y-values are scaled for rendering.
  public enum YScaleMode {
    /// Uses the range [min(values), max(values)] with a small padding.
    case minToMax(padding: Double = 0.05)
    /// Uses the range [0, max(values)].
    case zeroToMax
    /// Uses a fixed range [0, 1]. Values outside are clamped.
    case unit
  }

  /// Determines how the line color is chosen.
  public enum LineColorMode {
    /// Always use system accent color (or systemBlue as a fallback).
    case accent
    /// Use traffic-light style based on the most recent value (interpreted as 0...1):
    /// - <= 0.60 => accent, <= 0.85 => systemOrange, otherwise systemRed
    case memoryPressure
  }

  // MARK: - Public API

  /// Data points for the sparkline. Setting this triggers a redraw.
  public var values: [Double] = [] {
    didSet { setNeedsDisplay(bounds) }
  }

  /// Maximum number of values to retain when calling `appendValue`.
  public var maxValues: Int = 120

  /// Insets for the drawing area.
  public var contentInsets: NSEdgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8) {
    didSet { invalidateIntrinsicContentSize(); setNeedsDisplay(bounds) }
  }

  /// Width of the sparkline stroke.
  public var lineWidth: CGFloat = 1.5 {
    didSet { setNeedsDisplay(bounds) }
  }

  /// Renders a subtle gradient fill under the sparkline when enabled.
  public var showsGradientFill: Bool = true {
    didSet { setNeedsDisplay(bounds) }
  }

  /// How to scale Y values when rendering.
  public var yScaleMode: YScaleMode = .minToMax() {
    didSet { setNeedsDisplay(bounds) }
  }

  /// How to color the sparkline.
  public var lineColorMode: LineColorMode = .accent {
    didSet { setNeedsDisplay(bounds) }
  }

  /// Corner radius applied to the clipping path of the drawing rect.
  public var cornerRadius: CGFloat = 4 {
    didSet { setNeedsDisplay(bounds) }
  }

  /// Optional shadow to give the line a subtle glow/sparkle.
  public var lineShadowBlurRadius: CGFloat = 2 {
    didSet { setNeedsDisplay(bounds) }
  }

  // MARK: - Init

  public override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    commonInit()
  }

  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    wantsLayer = true
    canDrawConcurrently = true
    setAccessibilityRole(.image)
    setAccessibilityLabel("Sparkline")
  }

  // MARK: - Layout

  /// Makes the view expand horizontally and define a compact, consistent height.
  public override var intrinsicContentSize: NSSize {
    return NSSize(width: NSView.noIntrinsicMetric, height: 28)
  }

  public override var isFlipped: Bool {
    // Keep origin at bottom-left to make graph math straightforward.
    return false
  }

  // MARK: - Drawing

  public override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    // Ensure we have something to draw.
    guard values.count >= 2 else {
      drawPlaceholder(in: dirtyRect)
      return
    }

    // Clip drawing area with rounded corners for a polished look.
    let clipRect = bounds.insetBy(dx: 0.5, dy: 0.5)
    let clipPath = NSBezierPath(roundedRect: clipRect, xRadius: cornerRadius, yRadius: cornerRadius)
    clipPath.addClip()

    // Determine drawing rect inside content insets.
    let drawRect = clipRect.insetBy(
      dx: contentInsets.left + contentInsets.right > 0 ? contentInsets.left : 0,
      dy: contentInsets.top + contentInsets.bottom > 0 ? contentInsets.top : 0
    )
    let innerRect = NSRect(
      x: drawRect.origin.x,
      y: drawRect.origin.y,
      width: max(0, clipRect.width - contentInsets.left - contentInsets.right),
      height: max(0, clipRect.height - contentInsets.top - contentInsets.bottom)
    )

    // Background track for subtle contrast using system colors.
    NSColor.quaternaryLabelColor.withAlphaComponent(0.15).setFill()
    NSBezierPath(roundedRect: innerRect, xRadius: 2, yRadius: 2).fill()

    // Resolve color based on current mode and last value (when applicable).
    let strokeColor = resolveStrokeColor()

    // Build the sparkline path.
    let path = NSBezierPath()
    path.lineJoinStyle = .round
    path.lineCapStyle = .round
    path.lineWidth = lineWidth

    let normalized = normalizedValues()
    if normalized.isEmpty {
      drawPlaceholder(in: dirtyRect)
      return
    }

    let stepX = innerRect.width / CGFloat(max(1, normalized.count - 1))
    var x = innerRect.minX
    let yMin = innerRect.minY
    let yMax = innerRect.maxY

    // Map normalized 0...1 to y within the inner rect.
    func yPos(for v: CGFloat) -> CGFloat {
      return yMin + (v * (yMax - yMin))
    }

    // Move to first point.
    path.move(to: CGPoint(x: x, y: yPos(for: normalized[0])))

    // Build line.
    for i in 1..<normalized.count {
      x = innerRect.minX + CGFloat(i) * stepX
      path.line(to: CGPoint(x: x, y: yPos(for: normalized[i])))
    }

    // Optional gradient fill under the line for a subtle "sparkle".
    if showsGradientFill {
      let fillPath = path.copy() as! NSBezierPath
      fillPath.lineJoinStyle = .miter
      fillPath.lineCapStyle = .butt

      // Close the path along the bottom to create a polygon for the gradient area.
      fillPath.line(to: CGPoint(x: innerRect.maxX, y: innerRect.minY))
      fillPath.line(to: CGPoint(x: innerRect.minX, y: innerRect.minY))
      fillPath.close()

      let topColor = strokeColor.withAlphaComponent(0.25)
      let bottomColor = strokeColor.withAlphaComponent(0.06)
      if let gradient = NSGradient(colors: [topColor, bottomColor]) {
        gradient.draw(in: fillPath, angle: 90)
      } else {
        bottomColor.setFill()
        fillPath.fill()
      }
    }

    // Draw the sparkline stroke with a subtle shadow.
    let shadow = NSShadow()
    shadow.shadowBlurRadius = lineShadowBlurRadius
    shadow.shadowOffset = .zero
    shadow.shadowColor = strokeColor.withAlphaComponent(0.35)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    strokeColor.setStroke()
    path.stroke()
    NSGraphicsContext.restoreGraphicsState()
  }

  // MARK: - Public helpers

  /// Appends a value and trims the buffer to `maxValues`.
  public func appendValue(_ value: Double) {
    values.append(value)
    if values.count > maxValues {
      values.removeFirst(values.count - maxValues)
    }
    setNeedsDisplay(bounds)
  }

  /// Replaces the values and optionally caps them to `maxValues`.
  public func setValues(_ newValues: [Double], capToMax: Bool = true) {
    if capToMax, newValues.count > maxValues {
      self.values = Array(newValues.suffix(maxValues))
    } else {
      self.values = newValues
    }
  }

  // MARK: - Private helpers

  private func drawPlaceholder(in rect: NSRect) {
    // Draw a simple baseline as a placeholder to indicate the control's presence.
    let clipRect = bounds.insetBy(dx: 0.5, dy: 0.5)
    let drawRect = clipRect.insetBy(dx: contentInsets.left, dy: contentInsets.top)
    let baselineY = drawRect.midY

    let baseline = NSBezierPath()
    baseline.move(to: CGPoint(x: drawRect.minX, y: baselineY))
    baseline.line(to: CGPoint(x: drawRect.maxX, y: baselineY))
    baseline.lineWidth = 1

    NSColor.tertiaryLabelColor.withAlphaComponent(0.35).setStroke()
    baseline.stroke()
  }

  private func normalizedValues() -> [CGFloat] {
    guard !values.isEmpty else { return [] }

    switch yScaleMode {
    case .unit:
      let clamped = values.map { min(1.0, max(0.0, $0)) }
      return clamped.map { CGFloat($0) }

    case .zeroToMax:
      guard let maxV = values.max(), maxV > 0 else {
        return Array(repeating: 0, count: values.count).map { CGFloat($0) }
      }
      return values.map { CGFloat(max(0.0, min(1.0, $0 / maxV))) }

    case .minToMax(let padding):
      guard let minV = values.min(), let maxV = values.max() else {
        return Array(repeating: 0, count: values.count).map { CGFloat($0) }
      }
      var range = maxV - minV
      if range <= 1e-9 {
        // Avoid divide-by-zero; render as a flat line at mid-height.
        return Array(repeating: 0.5, count: values.count)
      }
      // Optional padding to avoid touching top/bottom borders.
      let pad = range * padding
      let denom = (maxV + pad) - (minV - pad)
      return values.map { v in
        let n = (v - (minV - pad)) / denom
        return CGFloat(max(0.0, min(1.0, n)))
      }
    }
  }

  private func resolveStrokeColor() -> NSColor {
    switch lineColorMode {
    case .accent:
      return accentColor()
    case .memoryPressure:
      // Interpret the most recent value as 0...1 for thresholding.
      let lastNormalized: CGFloat = {
        switch yScaleMode {
        case .unit:
          return CGFloat(min(1.0, max(0.0, values.last ?? 0)))
        case .zeroToMax:
          let maxV = values.max() ?? 1
          if maxV <= 0 { return 0 }
          return CGFloat(min(1.0, max(0.0, (values.last ?? 0) / maxV)))
        case .minToMax(let padding):
          if values.isEmpty { return 0 }
          let minV = values.min() ?? 0
          let maxV = values.max() ?? 1
          var range = maxV - minV
          if range <= 1e-9 { return 0.5 }
          let pad = range * padding
          let denom = (maxV + pad) - (minV - pad)
          let v = (values.last ?? minV) - (minV - pad)
          return CGFloat(max(0.0, min(1.0, v / denom)))
        }
      }()

      if lastNormalized > 0.85 {
        return NSColor.systemRed
      } else if lastNormalized > 0.60 {
        return NSColor.systemOrange
      } else {
        return accentColor()
      }
    }
  }

  private func accentColor() -> NSColor {
    if #available(macOS 10.14, *) {
      return NSColor.controlAccentColor
    } else {
      return NSColor.systemBlue
    }
  }

  // MARK: - Appearance

  public override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    // Redraw to adjust to light/dark changes since we use dynamic system colors.
    setNeedsDisplay(bounds)
  }
}