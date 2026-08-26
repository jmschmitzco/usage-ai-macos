// ============================================================
//  Usage A.I  -  Claude + ChatGPT (Codex)  -  versao macOS
// ============================================================
//  Icone na barra de menus com o uso dos dois servicos.
//  - Passar o mouse: previa com as barras e o icone de cada marca
//  - Clique esquerdo: painel com detalhes (5h, semanal, plano...)
//  - Clique direito: menu (atualizar, iniciar com o sistema, sair)
//
//  Seguranca: os tokens sao lidos de onde os CLIs oficiais ja os
//  guardam (arquivo ou Chaveiro) e usados SOMENTE no cabecalho
//  Authorization das duas APIs oficiais (api.anthropic.com e
//  chatgpt.com). Nada e gravado em disco. Nenhum outro destino.
// ============================================================

import AppKit
import Foundation

// MARK: - Modelo de dados

struct Cota {
    let rotulo: String
    let percent: Double
    let reset: Date?
}

struct Resultado {
    var cotas: [Cota] = []
    var plano: String = ""
    var erro: String? = nil
}

final class Estado {
    static let compartilhado = Estado()
    var claude = Resultado(erro: "Carregando...")
    var codex = Resultado(erro: "Carregando...")
    var atualizado: Date? = nil

    /// Percentual do uso semanal (nil quando em erro)
    func semanal(_ r: Resultado) -> Double? {
        if r.erro != nil { return nil }
        if let s = r.cotas.first(where: { $0.rotulo == "Semanal" }) { return s.percent }
        return r.cotas.map { $0.percent }.max()
    }
}

// MARK: - Aparencia (mesmo padrao da versao Windows)

enum Estilo {
    static let fundoJanela = NSColor(calibratedRed: 44/255, green: 44/255, blue: 44/255, alpha: 1)
    static let trilho = NSColor(calibratedRed: 12/255, green: 12/255, blue: 12/255, alpha: 1)
    static let textoClaro = NSColor.white
    static let textoFraco = NSColor(calibratedWhite: 0.59, alpha: 1)
    static let erro = NSColor(calibratedRed: 220/255, green: 120/255, blue: 120/255, alpha: 1)
    static let raioJanela: CGFloat = 8

    /// Cor conforme o quanto ja foi gasto: ate 30% verde, 30-70% amarelo, acima vermelho
    static func corUso(_ pct: Double) -> NSColor {
        if pct <= 30 { return NSColor(calibratedRed: 37/255, green: 211/255, blue: 102/255, alpha: 1) }
        if pct <= 70 { return NSColor(calibratedRed: 250/255, green: 196/255, blue: 36/255, alpha: 1) }
        return NSColor(calibratedRed: 244/255, green: 63/255, blue: 63/255, alpha: 1)
    }

    /// Versao clareada da cor, usada nas listras
    static func corClara(_ c: NSColor, _ fator: CGFloat = 0.22) -> NSColor {
        let base = c.usingColorSpace(.deviceRGB) ?? c
        func m(_ v: CGFloat) -> CGFloat { v + (1 - v) * fator }
        return NSColor(calibratedRed: m(base.redComponent), green: m(base.greenComponent), blue: m(base.blueComponent), alpha: 1)
    }
}

// MARK: - Barra de progresso desenhada (listras animadas)

final class BarraView: NSView {
    var pct: Double = 0
    var texto: String = ""
    var icone: NSImage? = nil
    var raio: CGFloat = 0
    var fatorBorda: CGFloat = 0.12
    var fase: CGFloat = 0

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setShouldAntialias(true)

        let w = bounds.width
        let h = bounds.height

        // Com icone, a barra ocupa uma faixa central e o icone sobra por cima
        let bh: CGFloat = icone != nil ? (h * 0.58).rounded() : h
        let by: CGFloat = ((h - bh) / 2).rounded()

        let espBranca = max(2, (bh * fatorBorda).rounded())
        let espEscura = max(1, (bh * 0.05).rounded())
        let r = min(raio, bh / 2)

        // Moldura branca externa
        let fora = NSBezierPath(roundedRect: NSRect(x: 0, y: by, width: w, height: bh), xRadius: r, yRadius: r)
        NSColor.white.setFill()
        fora.fill()

        // Interior escuro: linha fina de separacao e trilho vazio
        let rInt = max(0, r - espBranca)
        let dentro = NSBezierPath(roundedRect: NSRect(x: espBranca, y: by + espBranca,
                                                     width: w - 2 * espBranca, height: bh - 2 * espBranca),
                                  xRadius: rInt, yRadius: rInt)
        Estilo.trilho.setFill()
        dentro.fill()

        // Area util do preenchimento
        let x0 = espBranca + espEscura
        let y0 = by + espBranca + espEscura
        let iw = w - 2 * (espBranca + espEscura)
        let ih = bh - 2 * (espBranca + espEscura)
        guard iw > 0, ih > 0 else { return }

        let cor = Estilo.corUso(pct)
        let lw = iw * CGFloat(max(0, min(pct, 100))) / 100
        let incl = ih * 0.55

        if lw > 0 {
            ctx.saveGState()
            let rFill = max(0, r - espBranca - espEscura)
            NSBezierPath(roundedRect: NSRect(x: x0, y: y0, width: iw, height: ih),
                         xRadius: rFill, yRadius: rFill).addClip()

            // Preenchimento com a ponta inclinada (topo avanca mais que a base)
            let dir = min(x0 + lw + incl / 2, x0 + iw)
            let dirBase = max(x0, x0 + lw - incl / 2)
            let fill = NSBezierPath()
            fill.move(to: NSPoint(x: x0, y: y0))
            fill.line(to: NSPoint(x: dir, y: y0))
            fill.line(to: NSPoint(x: dirBase, y: y0 + ih))
            fill.line(to: NSPoint(x: x0, y: y0 + ih))
            fill.close()
            cor.setFill()
            fill.fill()

            // Listras inclinadas animadas, num tom mais claro da propria cor
            ctx.saveGState()
            fill.addClip()
            Estilo.corClara(cor).setFill()
            let faixa = ih * 0.38
            let periodo = faixa * 2
            var sx = x0 - incl - periodo + fase.truncatingRemainder(dividingBy: periodo)
            let limite = x0 + lw + incl + periodo
            while sx < limite {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: sx, y: y0 + ih))
                p.line(to: NSPoint(x: sx + faixa, y: y0 + ih))
                p.line(to: NSPoint(x: sx + faixa + incl, y: y0))
                p.line(to: NSPoint(x: sx + incl, y: y0))
                p.close()
                p.fill()
                sx += periodo
            }
            ctx.restoreGState()
            ctx.restoreGState()
        }

        // Posicao do icone: com preenchimento curto ele encosta no inicio da barra
        let iconLado = h
        let iconMeio = iconLado / 2
        var iconCx: CGFloat = 0
        if icone != nil {
            iconCx = max(x0 + iconMeio - espBranca, min(x0 + lw, w - iconMeio))
        }

        if !texto.isEmpty {
            desenhaNumero(x0: x0, y0: y0, iw: iw, ih: ih, lw: lw, incl: incl,
                          iconCx: iconCx, iconMeio: iconMeio)
        }

        // Icone da marca cavalgando a ponta do preenchimento
        if let img = icone {
            img.draw(in: NSRect(x: iconCx - iconMeio, y: 0, width: iconLado, height: iconLado),
                     from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
        }
    }

    /// Numero da porcentagem: peso pesado da fonte do sistema, encostado na
    /// extrema direita do preenchimento (ou logo apos ele, quando nao cabe)
    private func desenhaNumero(x0: CGFloat, y0: CGFloat, iw: CGFloat, ih: CGFloat,
                               lw: CGFloat, incl: CGFloat, iconCx: CGFloat, iconMeio: CGFloat) {
        var tamanho = ih * 0.66 / 0.72
        var fonte = NSFont.systemFont(ofSize: tamanho, weight: .black)
        var attrs: [NSAttributedString.Key: Any] = [.font: fonte, .foregroundColor: NSColor.white]
        var medida = (texto as NSString).size(withAttributes: attrs)

        let margem = max(3, ih * 0.22)

        // Acima de 10% o numero fica sempre dentro do preenchimento: se nao
        // couber no tamanho cheio, encolhe ate caber em vez de sair para fora
        if icone == nil && pct >= 10 {
            let disponivel = (lw - incl / 2 - 2 * margem) * 0.92
            if disponivel > 0 && medida.width > disponivel {
                let fator = disponivel / medida.width
                if fator > 0.45 {
                    tamanho *= fator
                    fonte = NSFont.systemFont(ofSize: tamanho, weight: .black)
                    attrs[.font] = fonte
                    medida = (texto as NSString).size(withAttributes: attrs)
                }
            }
        }

        var direita: CGFloat
        if icone != nil {
            let folga = iconMeio * 0.78
            direita = iconCx - folga - margem
            if direita - medida.width < x0 + margem {
                direita = min(iconCx + folga + margem + medida.width, x0 + iw - margem)
            }
        } else {
            direita = x0 + lw - incl / 2 - margem
            if direita - medida.width < x0 + margem {
                if pct >= 10 {
                    direita = x0 + margem + medida.width
                } else {
                    direita = min(x0 + lw + margem + medida.width, x0 + iw - margem)
                }
            }
        }

        let esquerda = direita - medida.width
        // Sobre o amarelo o branco some, entao ali o numero vai em preto
        let sobreFaixa = esquerda >= x0 && direita <= x0 + lw
        attrs[.foregroundColor] = (sobreFaixa && pct > 30 && pct <= 70)
            ? NSColor(calibratedWhite: 0.08, alpha: 1) : NSColor.white

        let y = y0 + (ih - medida.height) / 2
        (texto as NSString).draw(at: NSPoint(x: esquerda, y: y), withAttributes: attrs)
    }
}

// MARK: - Leitura de credenciais

enum Credenciais {
    /// Token do Claude Code: arquivo ~/.claude/.credentials.json ou, no macOS,
    /// o item guardado no Chaveiro pelo proprio CLI
    static func claude() -> String? {
        let caminho = ("~/.claude/.credentials.json" as NSString).expandingTildeInPath
        if let dados = FileManager.default.contents(atPath: caminho),
           let token = tokenClaude(de: dados) {
            return token
        }
        if let saida = executa("/usr/bin/security",
                               ["find-generic-password", "-s", "Claude Code-credentials", "-w"]),
           let dados = saida.data(using: .utf8),
           let token = tokenClaude(de: dados) {
            return token
        }
        return nil
    }

    private static func tokenClaude(de dados: Data) -> String? {
        guard let raiz = try? JSONSerialization.jsonObject(with: dados) as? [String: Any],
              let oauth = raiz["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else { return nil }
        return token
    }

    /// Token e conta do Codex: ~/.codex/auth.json
    static func codex() -> (token: String, conta: String?)? {
        let caminho = ("~/.codex/auth.json" as NSString).expandingTildeInPath
        guard let dados = FileManager.default.contents(atPath: caminho),
              let raiz = try? JSONSerialization.jsonObject(with: dados) as? [String: Any],
              let tokens = raiz["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String, !token.isEmpty else { return nil }
        return (token, tokens["account_id"] as? String)
    }

    private static func executa(_ caminho: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: caminho)
        p.arguments = args
        let saida = Pipe()
        p.standardOutput = saida
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let dados = saida.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        return String(data: dados, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Consulta as APIs

enum Api {
    static let urlUsoClaude = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let urlPerfilClaude = URL(string: "https://api.anthropic.com/api/oauth/profile")!
    static let urlUsoCodex = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    /// Coleta os dois servicos fora da thread principal e devolve no fim
    static func coletar(_ pronto: @escaping (Resultado, Resultado) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let c = usoClaude()
            let g = usoCodex()
            DispatchQueue.main.async { pronto(c, g) }
        }
    }

    private static func json(_ url: URL, _ headers: [String: String]) -> [String: Any]? {
        var req = URLRequest(url: url, timeoutInterval: 20)
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        var corpo: Data? = nil
        let espera = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { dados, resp, _ in
            if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) { corpo = dados }
            espera.signal()
        }.resume()
        _ = espera.wait(timeout: .now() + 25)
        guard let d = corpo else { return nil }
        return try? JSONSerialization.jsonObject(with: d) as? [String: Any]
    }

    private static func data(_ valor: Any?) -> Date? {
        if let s = valor as? String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: s) { return d }
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: s)
        }
        if let n = valor as? Double { return Date(timeIntervalSince1970: n) }
        return nil
    }

    static func usoClaude() -> Resultado {
        guard let token = Credenciais.claude() else { return Resultado(erro: "Claude Code nao logado") }
        let headers = ["Authorization": "Bearer \(token)",
                       "anthropic-beta": "oauth-2025-04-20",
                       "User-Agent": "claude-code/2.1.204"]
        guard let raiz = json(urlUsoClaude, headers) else {
            return Resultado(erro: "Falha ao consultar (token expirado?)")
        }

        var cotas: [Cota] = []
        for (chave, valor) in raiz {
            guard let d = valor as? [String: Any], let util = d["utilization"] as? Double else { continue }
            let reset = data(d["resets_at"])
            let pct = util.rounded()
            // Oculta cotas inativas (0% e sem janela de reset)
            if pct == 0 && reset == nil { continue }
            let rotulo: String
            if chave == "five_hour" { rotulo = "Sessao (5h)" }
            else if chave == "seven_day" { rotulo = "Semanal" }
            else if chave.hasPrefix("seven_day_") {
                rotulo = "Semanal " + chave.dropFirst("seven_day_".count).replacingOccurrences(of: "_", with: " ").capitalized
            } else {
                rotulo = chave.replacingOccurrences(of: "_", with: " ").capitalized
            }
            cotas.append(Cota(rotulo: rotulo, percent: pct, reset: reset))
        }

        // Limites por modelo chegam apenas no array "limits", via scope.model
        if let limites = raiz["limits"] as? [[String: Any]] {
            for lim in limites {
                guard let escopo = lim["scope"] as? [String: Any],
                      let modelo = escopo["model"] as? [String: Any],
                      let nome = modelo["display_name"] as? String else { continue }
                if cotas.contains(where: { $0.rotulo.contains(nome) }) { continue }
                let reset = data(lim["resets_at"])
                let pct = ((lim["percent"] as? Double) ?? 0).rounded()
                if pct == 0 && reset == nil { continue }
                cotas.append(Cota(rotulo: "Semanal \(nome)", percent: pct, reset: reset))
            }
        }

        if cotas.isEmpty { return Resultado(erro: "Resposta sem cotas") }
        cotas.sort { ordem($0.rotulo) < ordem($1.rotulo) }

        // Plano contratado: "default_claude_max_20x" -> "Max 20x"
        var plano = ""
        if let perfil = json(urlPerfilClaude, headers),
           let org = perfil["organization"] as? [String: Any],
           var tier = org["rate_limit_tier"] as? String {
            for prefixo in ["default_", "claude_"] where tier.hasPrefix(prefixo) {
                tier = String(tier.dropFirst(prefixo.count))
            }
            plano = tier.replacingOccurrences(of: "_", with: " ").capitalized
            plano = plano.replacingOccurrences(of: "20X", with: "20x")
        }
        return Resultado(cotas: cotas, plano: plano)
    }

    private static func ordem(_ rotulo: String) -> Int {
        if rotulo.hasPrefix("Sessao") { return 0 }
        if rotulo == "Semanal" { return 1 }
        return 2
    }

    static func usoCodex() -> Resultado {
        guard let cred = Credenciais.codex() else { return Resultado(erro: "Codex nao logado") }
        var headers = ["Authorization": "Bearer \(cred.token)",
                       "Accept": "application/json",
                       "User-Agent": "UsageAI/1.0"]
        if let conta = cred.conta { headers["ChatGPT-Account-Id"] = conta }
        guard let raiz = json(urlUsoCodex, headers),
              let rl = raiz["rate_limit"] as? [String: Any] else {
            return Resultado(erro: "Falha ao consultar (token expirado?)")
        }

        var cotas: [Cota] = []
        for (chave, rotulo) in [("primary_window", "Sessao (5h)"), ("secondary_window", "Semanal")] {
            guard let j = rl[chave] as? [String: Any], let usado = j["used_percent"] as? Double else { continue }
            var reset = data(j["reset_at"]) ?? data(j["resets_at"])
            if reset == nil, let s = j["reset_after_seconds"] as? Double { reset = Date().addingTimeInterval(s) }
            cotas.append(Cota(rotulo: rotulo, percent: usado.rounded(), reset: reset))
        }
        if cotas.isEmpty { return Resultado(erro: "Resposta sem janelas de uso") }
        let plano = (raiz["plan_type"] as? String)?.capitalized ?? ""
        return Resultado(cotas: cotas, plano: plano)
    }
}

// MARK: - Textos

enum Texto {
    static func reset(_ d: Date?) -> String {
        guard let d = d else { return "" }
        let delta = d.timeIntervalSinceNow
        if delta < 0 { return "Reiniciando..." }
        let hora = DateFormatter()
        hora.dateFormat = "HH:mm"
        if delta < 24 * 3600 {
            let h = Int(delta) / 3600
            let m = (Int(delta) % 3600) / 60
            return String(format: "Reinicia em %dh%02d (%@)", h, m, hora.string(from: d))
        }
        let dia = DateFormatter()
        dia.locale = Locale(identifier: "pt_BR")
        dia.dateFormat = "EEE"
        return "Reinicia \(dia.string(from: d).lowercased()) \(hora.string(from: d))"
    }

    static func carimbo(_ d: Date?) -> String {
        guard let d = d else { return "" }
        let f = DateFormatter()
        f.dateFormat = "dd/MM HH:mm"
        return f.string(from: d)
    }
}

// MARK: - Painel de detalhes (clique)

final class PainelView: NSView {
    private let largura: CGFloat = 320

    init(estado: Estado, logos: [String: NSImage]) {
        super.init(frame: NSRect(x: 0, y: 0, width: largura, height: 10))
        wantsLayer = true
        layer?.backgroundColor = Estilo.fundoJanela.cgColor

        var y: CGFloat = 14

        // Data/hora da ultima coleta, no canto superior direito
        if estado.atualizado != nil {
            let c = rotulo(Texto.carimbo(estado.atualizado), tamanho: 11, cor: Estilo.textoFraco)
            c.alignment = .right
            c.frame = NSRect(x: largura - 136, y: y + 3, width: 120, height: 18)
            addSubview(c)
        }

        secao("Claude", estado.claude, logos["claude"], &y)
        secao("ChatGPT", estado.codex, logos["gpt"], &y)

        frame = NSRect(x: 0, y: 0, width: largura, height: y + 4)
        // Coordenadas de cima para baixo: inverte os subviews no fim
        for v in subviews { v.frame.origin.y = frame.height - v.frame.origin.y - v.frame.height }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func rotulo(_ texto: String, tamanho: CGFloat, cor: NSColor, negrito: Bool = false) -> NSTextField {
        let t = NSTextField(labelWithString: texto)
        t.font = negrito ? NSFont.boldSystemFont(ofSize: tamanho) : NSFont.systemFont(ofSize: tamanho)
        t.textColor = cor
        t.backgroundColor = .clear
        t.isBordered = false
        t.sizeToFit()
        return t
    }

    private func secao(_ nome: String, _ r: Resultado, _ logo: NSImage?, _ y: inout CGFloat) {
        var textoX: CGFloat = 16
        if let img = logo {
            let iv = NSImageView(frame: NSRect(x: 16, y: y, width: 24, height: 24))
            iv.image = img
            iv.imageScaling = .scaleProportionallyUpOrDown
            addSubview(iv)
            textoX = 48
        }
        let titulo = rotulo(nome, tamanho: 15, cor: .white, negrito: true)
        titulo.frame.origin = NSPoint(x: textoX, y: y + 2)
        addSubview(titulo)
        y += 30

        if !r.plano.isEmpty {
            let p = rotulo("Plano \(r.plano)", tamanho: 11, cor: Estilo.textoFraco)
            p.frame.origin = NSPoint(x: 16, y: y)
            addSubview(p)
            y += 24
        } else {
            y += 4
        }

        if let erro = r.erro {
            let e = rotulo(erro, tamanho: 12, cor: Estilo.erro)
            e.frame.origin = NSPoint(x: 16, y: y)
            addSubview(e)
            y += 30
            return
        }

        for cota in r.cotas {
            let nomeCota = rotulo(cota.rotulo, tamanho: 12, cor: .white)
            nomeCota.frame.origin = NSPoint(x: 16, y: y)
            addSubview(nomeCota)
            y += 24

            let barra = BarraView(frame: NSRect(x: 16, y: y, width: largura - 32, height: 24))
            barra.pct = cota.percent
            barra.texto = "\(Int(cota.percent))%"
            barra.raio = Estilo.raioJanela
            barra.fatorBorda = 0.08
            Animacao.compartilhada.registra(barra)
            addSubview(barra)
            y += 28

            if cota.reset != nil {
                let res = rotulo(Texto.reset(cota.reset), tamanho: 11, cor: Estilo.textoFraco)
                res.frame.origin = NSPoint(x: 16, y: y)
                addSubview(res)
                y += 20
            }
            y += 6
        }
        y += 10
    }
}

// MARK: - Previa do hover

final class PreviaView: NSView {
    init(estado: Estado, logos: [String: NSImage]) {
        let largura: CGFloat = 252
        super.init(frame: NSRect(x: 0, y: 0, width: largura, height: 10))
        wantsLayer = true
        layer?.backgroundColor = Estilo.fundoJanela.cgColor

        let alturaLinha: CGFloat = 34
        var y: CGFloat = 10
        let itens: [(String, Resultado)] = [("claude", estado.claude), ("gpt", estado.codex)]

        for (chave, r) in itens {
            if let pct = estado.semanal(r) {
                let barra = BarraView(frame: NSRect(x: 12, y: y, width: largura - 24, height: alturaLinha))
                barra.pct = pct
                barra.texto = "\(Int(pct))%"
                barra.icone = logos[chave]
                barra.raio = Estilo.raioJanela
                barra.fatorBorda = 0.08
                Animacao.compartilhada.registra(barra)
                addSubview(barra)
            } else {
                let t = NSTextField(labelWithString: r.erro ?? "sem dados")
                t.font = NSFont.systemFont(ofSize: 12)
                t.textColor = Estilo.erro
                t.backgroundColor = .clear
                t.isBordered = false
                t.sizeToFit()
                t.frame.origin = NSPoint(x: 12, y: y + 8)
                addSubview(t)
            }
            y += alturaLinha + 8
        }
        frame = NSRect(x: 0, y: 0, width: largura, height: y + 2)
        for v in subviews { v.frame.origin.y = frame.height - v.frame.origin.y - v.frame.height }
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Animacao das listras

final class Animacao {
    static let compartilhada = Animacao()
    private var barras: [BarraView] = []
    private var fase: CGFloat = 0
    private var timer: Timer?

    func registra(_ b: BarraView) {
        barras.append(b)
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in self?.passo() }
        }
    }

    private func passo() {
        fase += 0.8
        barras.removeAll { $0.window == nil && $0.superview == nil }
        for b in barras where b.window != nil {
            b.fase = fase
            b.needsDisplay = true
        }
    }
}

// MARK: - Aplicativo

final class App: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private var popover: NSPopover?
    private var previa: NSPanel?
    private var logos: [String: NSImage] = [:]
    private let estado = Estado.compartilhado

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        carregaLogos()

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let botao = item.button {
            botao.image = imagemBarraMenus()
            botao.imagePosition = .imageOnly
            botao.target = self
            botao.action = #selector(cliqueNoIcone(_:))
            botao.sendAction(on: [.leftMouseUp, .rightMouseUp])
            let area = NSTrackingArea(rect: botao.bounds,
                                      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                      owner: self, userInfo: nil)
            botao.addTrackingArea(area)
        }

        atualiza()
        Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in self?.atualiza() }
    }

    private func caminhoRecurso(_ nome: String) -> String? {
        // Funciona tanto solto na pasta quanto dentro de um .app
        if let r = Bundle.main.path(forResource: nome, ofType: "png") { return r }
        let vizinho = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent().appendingPathComponent("\(nome).png").path
        return FileManager.default.fileExists(atPath: vizinho) ? vizinho : nil
    }

    private func carregaLogos() {
        if let p = caminhoRecurso("LogoClaude"), let i = NSImage(contentsOfFile: p) { logos["claude"] = i }
        if let p = caminhoRecurso("LogoChatGPT"), let i = NSImage(contentsOfFile: p) { logos["gpt"] = i }
    }

    private func imagemBarraMenus() -> NSImage {
        if let p = caminhoRecurso("MenuBarIcon"), let img = NSImage(contentsOfFile: p) {
            img.size = NSSize(width: 18, height: 18)
            return img
        }
        let img = NSImage(size: NSSize(width: 18, height: 18))
        img.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 2, y: 6, width: 14, height: 6)).fill()
        img.unlockFocus()
        return img
    }

    private func atualiza() {
        Api.coletar { [weak self] claude, codex in
            guard let self = self else { return }
            self.estado.claude = claude
            self.estado.codex = codex
            self.estado.atualizado = Date()
        }
    }

    // MARK: Interacao

    @objc private func cliqueNoIcone(_ sender: Any?) {
        escondePrevia()
        if NSApp.currentEvent?.type == .rightMouseUp {
            mostraMenu()
        } else {
            mostraPainel()
        }
    }

    override func mouseEntered(with event: NSEvent) { mostraPrevia() }
    override func mouseExited(with event: NSEvent) { escondePrevia() }

    private func mostraPainel() {
        if let p = popover, p.isShown { p.performClose(nil); popover = nil; return }
        guard let botao = item.button else { return }
        let p = NSPopover()
        let conteudo = PainelView(estado: estado, logos: logos)
        let vc = NSViewController()
        vc.view = conteudo
        p.contentViewController = vc
        p.contentSize = conteudo.frame.size
        p.behavior = .transient
        p.appearance = NSAppearance(named: .darkAqua)
        p.show(relativeTo: botao.bounds, of: botao, preferredEdge: .minY)
        popover = p
    }

    private func mostraPrevia() {
        guard previa == nil, popover?.isShown != true, let botao = item.button,
              let janelaBotao = botao.window else { return }
        let conteudo = PreviaView(estado: estado, logos: logos)
        let painel = NSPanel(contentRect: conteudo.frame, styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        painel.isOpaque = false
        painel.backgroundColor = .clear
        painel.hasShadow = true
        painel.level = .statusBar
        painel.contentView = conteudo
        conteudo.wantsLayer = true
        conteudo.layer?.cornerRadius = Estilo.raioJanela
        conteudo.layer?.masksToBounds = true

        // Ancorado logo abaixo do icone na barra de menus
        let origemBotao = janelaBotao.convertPoint(toScreen: botao.frame.origin)
        let x = origemBotao.x + botao.frame.width / 2 - conteudo.frame.width / 2
        let y = origemBotao.y - conteudo.frame.height - 6
        painel.setFrameOrigin(NSPoint(x: x, y: y))
        painel.orderFrontRegardless()
        previa = painel
    }

    private func escondePrevia() {
        previa?.orderOut(nil)
        previa = nil
    }

    private func mostraMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Ver detalhes", action: #selector(acaoDetalhes), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Atualizar agora", action: #selector(acaoAtualizar), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Sair", action: #selector(acaoSair), keyEquivalent: "q"))
        for i in menu.items { i.target = self }
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func acaoDetalhes() { mostraPainel() }
    @objc private func acaoAtualizar() { atualiza() }
    @objc private func acaoSair() { NSApp.terminate(nil) }
}

// MARK: - Entrada

let app = NSApplication.shared
let delegado = App()
app.delegate = delegado
app.run()
