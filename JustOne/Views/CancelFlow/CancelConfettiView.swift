//
//  CancelConfettiView.swift
//  JustOne
//
//  Confetti burst effect shown when a retention offer is accepted
//  in the cancel flow.
//

import SwiftUI

struct CancelConfettiView: View {
    let origin: CGPoint
    private let colors: [Color] = [.justPrimary, .justSuccess, .justSecondary, .habitPink, .habitOrange, .yellow]
    private let count = 150

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                // Angle biased upward: -π (left) through -π/2 (up) to 0 (right)
                // with some spread below horizontal for a natural fountain effect
                let angle = Double.random(in: -(Double.pi * 0.95)...(-(Double.pi * 0.05)))
                CancelConfettiPiece(
                    color: colors[i % colors.count],
                    origin: origin,
                    angle: angle,
                    distance: CGFloat.random(in: 180...550),
                    delay: Double.random(in: 0...0.1)
                )
            }
        }
    }
}

private struct CancelConfettiPiece: View {
    let color: Color
    let origin: CGPoint
    let angle: Double
    let distance: CGFloat
    let delay: Double

    @State private var animate = false

    private let rotation = Double.random(in: 360...1080)
    private let size = CGSize(width: CGFloat.random(in: 6...10), height: CGFloat.random(in: 10...16))
    private var endX: CGFloat { cos(angle) * distance }
    private var endY: CGFloat { sin(angle) * distance }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: size.width, height: size.height)
            .rotationEffect(.degrees(animate ? rotation : 0))
            .scaleEffect(animate ? 1 : 0.2)
            .opacity(animate ? 0 : 1)
            .offset(x: animate ? endX : 0, y: animate ? endY : 0)
            .position(origin)
            .onAppear {
                withAnimation(.easeOut(duration: Double.random(in: 1.5...2.5)).delay(delay)) {
                    animate = true
                }
            }
    }
}
