import SwiftUI

/// I sette disegni della scala della forma, ridisegnati da zero come vettori.
///
/// Sono deliberatamente originali. Le illustrazioni della scala clinica piu'
/// nota sono opere protette, con una titolarita' per giunta contesa fra piu'
/// soggetti, e riprodurle avrebbe legato l'app a un permesso che non abbiamo.
/// L'ordinamento fisico (da compatto a liquido) non e' un'opera: e' cio' che
/// serve, e basta.
struct DisegnoForma: View {
    let forma: FormaFecale
    var altezza: CGFloat = 34

    var body: some View {
        Canvas { contesto, dimensione in
            let colore = Self.colore(forma)
            disegna(forma, in: contesto, dimensione: dimensione, colore: colore)
        }
        .frame(height: altezza)
        .accessibilityHidden(true)
    }

    static func colore(_ forma: FormaFecale) -> Color {
        switch forma.zona {
        case .compatta: Color(red: 0.62, green: 0.44, blue: 0.28)
        case .centrale: Color(red: 0.48, green: 0.36, blue: 0.24)
        case .molle:    Color(red: 0.55, green: 0.45, blue: 0.30)
        }
    }

    private func disegna(_ forma: FormaFecale, in contesto: GraphicsContext,
                         dimensione: CGSize, colore: Color) {
        let w = dimensione.width, h = dimensione.height
        let cy = h / 2
        let riempimento = GraphicsContext.Shading.color(colore)

        switch forma {
        case .pallineDure:
            let n = 5
            let r = min(h * 0.22, w / CGFloat(n * 3))
            let passo = w / CGFloat(n + 1)
            for i in 1...n {
                let x = passo * CGFloat(i)
                let dy = (i % 2 == 0 ? -1.0 : 1.0) * h * 0.06
                contesto.fill(Path(ellipseIn: CGRect(x: x - r, y: cy + dy - r,
                                                     width: r * 2, height: r * 2)), with: riempimento)
            }

        case .grumosa:
            // un unico corpo, ottenuto sovrapponendo lobi di raggio diverso
            let raggi: [CGFloat] = [0.30, 0.36, 0.31, 0.37, 0.29]
            let larghezza = w * 0.86
            let x0 = (w - larghezza) / 2
            for (i, k) in raggi.enumerated() {
                let r = h * k
                let x = x0 + larghezza * CGFloat(i) / CGFloat(raggi.count - 1)
                contesto.fill(Path(ellipseIn: CGRect(x: x - r, y: cy - r,
                                                     width: r * 2, height: r * 2)), with: riempimento)
            }

        case .conCrepe:
            let corpo = CGRect(x: w * 0.07, y: cy - h * 0.28, width: w * 0.86, height: h * 0.56)
            contesto.fill(Path(roundedRect: corpo, cornerRadius: h * 0.28), with: riempimento)
            var crepe = Path()
            for i in 1...4 {
                let x = corpo.minX + corpo.width * CGFloat(i) / 5
                crepe.move(to: CGPoint(x: x, y: corpo.minY + h * 0.08))
                crepe.addLine(to: CGPoint(x: x - w * 0.015, y: corpo.maxY - h * 0.08))
            }
            contesto.stroke(crepe, with: .color(.white.opacity(0.55)), lineWidth: max(1, h * 0.045))

        case .liscia:
            let corpo = CGRect(x: w * 0.05, y: cy - h * 0.26, width: w * 0.90, height: h * 0.52)
            contesto.fill(Path(roundedRect: corpo, cornerRadius: h * 0.26), with: riempimento)

        case .pezziMorbidi:
            let n = 3
            let larghezza = w * 0.24
            let passo = w / CGFloat(n + 1)
            for i in 1...n {
                let x = passo * CGFloat(i)
                let altezzaPezzo = h * (i == 2 ? 0.46 : 0.40)
                let r = CGRect(x: x - larghezza / 2, y: cy - altezzaPezzo / 2,
                               width: larghezza, height: altezzaPezzo)
                contesto.fill(Path(roundedRect: r, cornerRadius: altezzaPezzo * 0.45), with: riempimento)
            }

        case .poltiglia:
            // bordo irregolare, ottenuto perturbando un ovale con una serie fissa
            var p = Path()
            let passi = 40
            let perturbazioni: [CGFloat] = (0..<passi).map { i in
                let t = CGFloat(i)
                return 1 + 0.13 * sin(t * 1.7) + 0.08 * sin(t * 3.1 + 0.9)
            }
            for i in 0..<passi {
                let a = CGFloat(i) / CGFloat(passi) * .pi * 2
                let rx = w * 0.42 * perturbazioni[i]
                let ry = h * 0.30 * perturbazioni[i]
                let pt = CGPoint(x: w / 2 + cos(a) * rx, y: cy + sin(a) * ry)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            contesto.fill(p, with: riempimento)

        case .liquida:
            var p = Path()
            p.move(to: CGPoint(x: w * 0.03, y: cy))
            let onde = 4
            for i in 0..<onde {
                let x0 = w * 0.03 + (w * 0.94) * CGFloat(i) / CGFloat(onde)
                let x1 = w * 0.03 + (w * 0.94) * CGFloat(i + 1) / CGFloat(onde)
                p.addQuadCurve(to: CGPoint(x: x1, y: cy),
                               control: CGPoint(x: (x0 + x1) / 2,
                                                y: cy + (i % 2 == 0 ? -h * 0.16 : h * 0.16)))
            }
            p.addLine(to: CGPoint(x: w * 0.97, y: cy + h * 0.20))
            p.addLine(to: CGPoint(x: w * 0.03, y: cy + h * 0.20))
            p.closeSubpath()
            contesto.fill(p, with: .color(colore.opacity(0.75)))
            contesto.stroke(Path(ellipseIn: CGRect(x: w * 0.10, y: cy - h * 0.24,
                                                   width: w * 0.80, height: h * 0.48)),
                            with: .color(colore.opacity(0.35)),
                            style: StrokeStyle(lineWidth: max(1, h * 0.04), dash: [h * 0.10, h * 0.09]))
        }
    }
}

/// La striscia di scelta: e' il secondo dei tre tocchi necessari a registrare
/// un evento, quindi non ha titoli, spiegazioni o conferme.
struct StrisciaForme: View {
    @Environment(\.locale) private var locale
    @Binding var scelta: FormaFecale?
    var compatta: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ForEach(FormaFecale.allCases) { forma in
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    scelta = forma
                } label: {
                    HStack(spacing: 14) {
                        DisegnoForma(forma: forma, altezza: compatta ? 26 : 34)
                            .frame(width: compatta ? 66 : 88)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(LocalizedStringKey(forma.chiaveEtichetta))
                                .font(compatta ? .subheadline : .headline)
                            if !compatta {
                                Text(LocalizedStringKey(forma.chiaveDescrizione))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                        if scelta == forma {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                                .font(.title3)
                        }
                    }
                    .padding(.vertical, compatta ? 6 : 9)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(scelta == forma ? Color.accentColor.opacity(0.14) : Color.gray.opacity(0.09)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(scelta == forma ? Color.accentColor : .clear, lineWidth: 1.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: "\(forma.etichetta(locale)). \(forma.descrizione(locale))"))
                .accessibilityAddTraits(scelta == forma ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}
