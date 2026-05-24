import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Resultado de uma extração. `html` é sempre HTML válido (mesmo arquivos
/// .txt ou PDFs são embrulhados em `<p>...</p>`).
class ExtractedText {
  /// HTML do conteúdo extraído. Renderizado com flutter_html na tela de leitura.
  final String html;

  /// True se o formato de origem (DOCX) preserva formatação rich.
  /// PDF e TXT são planos.
  final bool hasFormatting;

  const ExtractedText({required this.html, required this.hasFormatting});

  /// Alias temporário pra compatibilidade com código que ainda usa `markdown`.
  /// TODO: remover após migração completa do callers.
  String get markdown => html;
}

/// Extrai conteúdo de um arquivo (.docx, .pdf, .txt) como HTML.
Future<ExtractedText> extractFile(String path) async {
  final lower = path.toLowerCase();
  if (lower.endsWith('.docx')) return extractDocxToHtml(path);
  if (lower.endsWith('.pdf')) return extractPdfToHtml(path);
  if (lower.endsWith('.txt')) {
    final txt = await File(path).readAsString();
    return ExtractedText(
      html: _plainTextToHtml(txt),
      hasFormatting: false,
    );
  }
  throw FormatException('Formato não suportado: $path');
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCX → HTML completo
//   preserva: bold, italic, underline, strikethrough, sub/sup, headings,
//             listas com nível (ul/ol/li), alinhamento, quebras explícitas
// ─────────────────────────────────────────────────────────────────────────────

const _wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

Future<ExtractedText> extractDocxToHtml(String path) async {
  final bytes = await File(path).readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);

  final docFile = archive.files.firstWhere(
        (f) => f.name == 'word/document.xml',
    orElse: () => throw const FormatException('DOCX sem word/document.xml'),
  );

  // DOCX armazena document.xml em UTF-8 — usar utf8.decode pra não
  // virar mojibake em caracteres latinos acentuados e diacríticos IAST.
  final xmlStr = utf8.decode(docFile.content as List<int>);
  final doc = XmlDocument.parse(xmlStr);

  // ── Lê word/numbering.xml (se existir) pra distinguir bullet vs numbered ──
  final numberingFile = archive.files
      .where((f) => f.name == 'word/numbering.xml')
      .firstOrNull;
  final numberingMap = numberingFile != null
      ? _parseNumberingXml(utf8.decode(numberingFile.content as List<int>))
      : <int, Map<int, String>>{};

  final body = doc.findAllElements('body', namespace: _wNs).firstOrNull;
  if (body == null) return const ExtractedText(html: '', hasFormatting: true);

  // ── Coleta paragraph descriptors (HTML inline + metadados de lista) ──
  final descritores = <_ParaDesc>[];
  for (final p in body.findElements('p', namespace: _wNs)) {
    final d = _parseParagraph(p, numberingMap);
    if (d != null) descritores.add(d);
  }

  // ── Comprime parágrafos vazios consecutivos (max 1 espaço entre blocos) ──
  final comprimidos = _comprimirVazios(descritores);

  // ── Mescla parágrafos quebrados artificialmente
  //    (continuações órfãs, ex: "Sangha." sozinho após "...refúgio a") ──
  final mesclados = _mesclarOrfaos(comprimidos);

  // ── Gera HTML com aninhamento correto de listas ──
  final html = _renderHtml(mesclados);
  return ExtractedText(html: html, hasFormatting: true);
}

/// Reduz sequências de parágrafos vazios a no máximo 1 (DOCX costuma ter
/// Enter triplo entre blocos — visualmente igual a um único Enter).
List<_ParaDesc> _comprimirVazios(List<_ParaDesc> entrada) {
  final saida = <_ParaDesc>[];
  bool ultimoVazio = false;
  for (final d in entrada) {
    if (d.isEmpty) {
      if (ultimoVazio) continue; // pula vazios consecutivos
      ultimoVazio = true;
      saida.add(d);
    } else {
      ultimoVazio = false;
      saida.add(d);
    }
  }
  // Remove vazios no começo e no fim
  while (saida.isNotEmpty && saida.first.isEmpty) {
    saida.removeAt(0);
  }
  while (saida.isNotEmpty && saida.last.isEmpty) {
    saida.removeLast();
  }
  return saida;
}

/// Mescla parágrafos órfãos. Heurística:
/// - Se o anterior termina em pontuação de fim de bloco (`.`, `?`, `!`, `|`, `:`),
///   é uma quebra intencional → não mescla.
/// - Se mudou contexto (heading, lista, alinhamento, indentação), também
///   é intencional → não mescla.
/// - Caso contrário (ex: termina com `,` ou sem pontuação E continua no
///   mesmo contexto), é PDF→Word wrap artificial → mescla com espaço.
List<_ParaDesc> _mesclarOrfaos(List<_ParaDesc> entrada) {
  if (entrada.length < 2) return entrada;

  // Caracteres que indicam fim real de bloco (não wrap artificial)
  final fimDeBloco = RegExp(r'[\.\?!\|:][\)"”’]*\s*$');
  final tagAberta = RegExp(r'<[^/][^>]*$');

  final saida = <_ParaDesc>[];
  for (final d in entrada) {
    if (saida.isEmpty) {
      saida.add(d);
      continue;
    }
    final anterior = saida.last;

    // Mudança de contexto = quebra intencional. Inclui indentação porque
    // intros tipo "Como diz...:" + quote indentada são intencionais.
    final mudaContexto = anterior.headingLevel != null ||
        d.headingLevel != null ||
        anterior.isList ||
        d.isList ||
        anterior.align != d.align ||
        anterior.marginLeftPx != d.marginLeftPx ||
        anterior.textIndentPx != d.textIndentPx;

    if (mudaContexto) {
      saida.add(d);
      continue;
    }

    final textoAnterior = _stripTags(anterior.inlineHtml).trimRight();
    final textoAtual = _stripTags(d.inlineHtml).trimLeft();

    // Parágrafo vazio → mantém como separador visual
    if (textoAnterior.isEmpty || textoAtual.isEmpty) {
      saida.add(d);
      continue;
    }

    final terminaBloco = fimDeBloco.hasMatch(textoAnterior);

    // Não mescla se anterior fechou um bloco, ou se tem tag HTML aberta
    if (terminaBloco || tagAberta.hasMatch(anterior.inlineHtml)) {
      saida.add(d);
      continue;
    }

    // Mescla — continuação no mesmo contexto, anterior não terminou bloco
    final juntos = _ParaDesc(
      inlineHtml: '${anterior.inlineHtml} ${d.inlineHtml}',
      headingLevel: anterior.headingLevel,
      isList: anterior.isList,
      isNumbered: anterior.isNumbered,
      listLevel: anterior.listLevel,
      align: anterior.align,
      marginLeftPx: anterior.marginLeftPx,
      textIndentPx: anterior.textIndentPx,
    );
    saida[saida.length - 1] = juntos;
  }
  return saida;
}

String _stripTags(String html) =>
    html.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ');

// ── Modelo intermediário de parágrafo ─────────────────────────────────────

class _ParaDesc {
  final String inlineHtml;
  final int? headingLevel; // null = parágrafo normal
  final bool isList;
  final bool isNumbered;
  final int listLevel;
  final String? align; // left/center/right/justify
  final double? marginLeftPx; // indentação esquerda em pixels
  final double? textIndentPx; // primeira linha (positivo) ou hanging (negativo)

  const _ParaDesc({
    required this.inlineHtml,
    this.headingLevel,
    this.isList = false,
    this.isNumbered = false,
    this.listLevel = 0,
    this.align,
    this.marginLeftPx,
    this.textIndentPx,
  });

  bool get isEmpty => inlineHtml.trim().isEmpty;
}

/// Parse `word/numbering.xml` → map numId → (level → numFmt).
/// Estrutura simplificada:
///   <w:numbering>
///     <w:abstractNum w:abstractNumId="0">
///       <w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/></w:lvl>
///       <w:lvl w:ilvl="1"><w:numFmt w:val="decimal"/></w:lvl>
///     </w:abstractNum>
///     <w:num w:numId="1">
///       <w:abstractNumId w:val="0"/>
///     </w:num>
///   </w:numbering>
Map<int, Map<int, String>> _parseNumberingXml(String xml) {
  final result = <int, Map<int, String>>{};
  try {
    final doc = XmlDocument.parse(xml);

    // 1. Coleta todas as definições abstratas: abstractNumId → (ilvl → numFmt)
    final abstratos = <int, Map<int, String>>{};
    for (final an in doc.findAllElements('abstractNum', namespace: _wNs)) {
      final id =
      int.tryParse(an.getAttribute('abstractNumId', namespace: _wNs) ?? '');
      if (id == null) continue;
      final niveis = <int, String>{};
      for (final lvl in an.findElements('lvl', namespace: _wNs)) {
        final ilvl =
        int.tryParse(lvl.getAttribute('ilvl', namespace: _wNs) ?? '');
        if (ilvl == null) continue;
        final fmt = lvl
            .findElements('numFmt', namespace: _wNs)
            .firstOrNull
            ?.getAttribute('val', namespace: _wNs);
        if (fmt != null) niveis[ilvl] = fmt;
      }
      abstratos[id] = niveis;
    }

    // 2. Mapeia num.numId → abstractNum.abstractNumId
    for (final n in doc.findAllElements('num', namespace: _wNs)) {
      final numId = int.tryParse(n.getAttribute('numId', namespace: _wNs) ?? '');
      if (numId == null) continue;
      final abstId = int.tryParse(n
          .findElements('abstractNumId', namespace: _wNs)
          .firstOrNull
          ?.getAttribute('val', namespace: _wNs) ??
          '');
      if (abstId != null && abstratos.containsKey(abstId)) {
        result[numId] = abstratos[abstId]!;
      }
    }
  } catch (_) {
    // numbering.xml malformado — ignora, todas as listas viram bullet
  }
  return result;
}

/// Decide se uma lista é numerada com base no numFmt do nível.
/// "bullet" → false. Qualquer outro formato conhecido (decimal, lowerRoman,
/// upperLetter, ordinal, etc.) → true.
bool _isFormatoNumerado(String fmt) {
  final lower = fmt.toLowerCase();
  if (lower == 'bullet' || lower == 'none') return false;
  return true;
}

_ParaDesc? _parseParagraph(
    XmlElement p, Map<int, Map<int, String>> numberingMap) {
  final pPr = p.findElements('pPr', namespace: _wNs).firstOrNull;

  // Estilo do parágrafo
  final pStyle = pPr
      ?.findElements('pStyle', namespace: _wNs)
      .firstOrNull
      ?.getAttribute('val', namespace: _wNs);
  final headingLevel = _headingLevel(pStyle);

  // Lista — numPr indica que faz parte de uma lista
  final numPr = pPr?.findElements('numPr', namespace: _wNs).firstOrNull;
  final isList = numPr != null;
  int listLevel = 0;
  bool isNumbered = false;
  if (isList) {
    final ilvl = numPr.findElements('ilvl', namespace: _wNs).firstOrNull;
    listLevel =
        int.tryParse(ilvl?.getAttribute('val', namespace: _wNs) ?? '0') ?? 0;

    final numIdEl = numPr.findElements('numId', namespace: _wNs).firstOrNull;
    final numId =
    int.tryParse(numIdEl?.getAttribute('val', namespace: _wNs) ?? '');

    // Consulta o map (extraído de numbering.xml) — numId + ilvl → numFmt
    if (numId != null && numberingMap.containsKey(numId)) {
      final niveis = numberingMap[numId]!;
      final fmt = niveis[listLevel] ?? niveis[0]; // fallback nível 0
      isNumbered = fmt != null && _isFormatoNumerado(fmt);
    } else {
      // Fallback heurístico se numbering.xml não disponível
      isNumbered = (pStyle ?? '').toLowerCase().contains('numlist') ||
          (pStyle ?? '').toLowerCase().contains('ordered');
    }
  }

  // Alinhamento
  final jc = pPr?.findElements('jc', namespace: _wNs).firstOrNull;
  final alignRaw = jc?.getAttribute('val', namespace: _wNs);
  final align = _normalizaAlign(alignRaw);

  // Indentação — <w:ind w:left="720" w:firstLine="360" w:hanging="..."/>
  //  Word usa "twips" (1/20 ponto). 1pt ≈ 1.33px no CSS.
  //  Conversão: twips → px ≈ twips / 15 (suficiente pra escala visual).
  double? marginLeftPx;
  double? textIndentPx;
  final ind = pPr?.findElements('ind', namespace: _wNs).firstOrNull;
  if (ind != null) {
    final left = int.tryParse(ind.getAttribute('left', namespace: _wNs) ?? '');
    if (left != null && left > 0) marginLeftPx = left / 15.0;

    final firstLine =
    int.tryParse(ind.getAttribute('firstLine', namespace: _wNs) ?? '');
    if (firstLine != null && firstLine != 0) textIndentPx = firstLine / 15.0;

    final hanging =
    int.tryParse(ind.getAttribute('hanging', namespace: _wNs) ?? '');
    if (hanging != null && hanging > 0) textIndentPx = -hanging / 15.0;
  }

  // Runs → inline HTML
  final inline = StringBuffer();
  for (final r in p.findElements('r', namespace: _wNs)) {
    inline.write(_runToHtml(r));
  }
  for (final hl in p.findElements('hyperlink', namespace: _wNs)) {
    // Hiperlinks contém runs filhos
    final inner = StringBuffer();
    for (final r in hl.findElements('r', namespace: _wNs)) {
      inner.write(_runToHtml(r));
    }
    if (inner.isNotEmpty) {
      inline.write('<a>${inner.toString()}</a>');
    }
  }

  final content = inline.toString().trim();
  // Parágrafo vazio → preserva como espaço (espaçamento entre blocos)
  if (content.isEmpty && headingLevel == null && !isList) {
    return const _ParaDesc(inlineHtml: '');
  }

  return _ParaDesc(
    inlineHtml: content,
    headingLevel: headingLevel,
    isList: isList,
    isNumbered: isNumbered,
    listLevel: listLevel,
    align: align,
    marginLeftPx: marginLeftPx,
    textIndentPx: textIndentPx,
  );
}

int? _headingLevel(String? style) {
  if (style == null) return null;
  final lower = style.toLowerCase();
  if (lower == 'title') return 1;
  if (lower.startsWith('heading')) {
    final n = int.tryParse(lower.replaceAll(RegExp(r'[^0-9]'), ''));
    if (n != null && n >= 1 && n <= 6) return n;
    return 2;
  }
  return null;
}

String? _normalizaAlign(String? raw) {
  if (raw == null) return null;
  switch (raw.toLowerCase()) {
    case 'center':
      return 'center';
    case 'right':
    case 'end':
      return 'right';
    case 'both':
    case 'justify':
      return 'justify';
    case 'left':
    case 'start':
      return null; // padrão, não precisa atribuir
    default:
      return null;
  }
}

String _runToHtml(XmlElement r) {
  final rPr = r.findElements('rPr', namespace: _wNs).firstOrNull;
  final isBold = rPr?.findElements('b', namespace: _wNs).isNotEmpty ?? false;
  final isItalic = rPr?.findElements('i', namespace: _wNs).isNotEmpty ?? false;
  final isUnderline =
      rPr?.findElements('u', namespace: _wNs).isNotEmpty ?? false;
  final isStrike =
      rPr?.findElements('strike', namespace: _wNs).isNotEmpty ?? false;

  // Sub/Superscript via <w:vertAlign val="subscript|superscript"/>
  final vertAlign = rPr
      ?.findElements('vertAlign', namespace: _wNs)
      .firstOrNull
      ?.getAttribute('val', namespace: _wNs);
  final isSubscript = vertAlign == 'subscript';
  final isSuperscript = vertAlign == 'superscript';

  // Cor (highlight ou color)
  final color = rPr
      ?.findElements('color', namespace: _wNs)
      .firstOrNull
      ?.getAttribute('val', namespace: _wNs);

  // Conteúdo do run
  final buf = StringBuffer();
  for (final child in r.children.whereType<XmlElement>()) {
    final name = child.name.local;
    if (name == 't') {
      buf.write(_escHtml(child.innerText));
    } else if (name == 'tab') {
      // &emsp; colapsa no flutter_html v3 dentro de <p>.
      // Usar span inline-block garante largura visual consistente.
      buf.write('<span style="display:inline-block;width:2em"> </span>');
    } else if (name == 'br') {
      buf.write('<br>');
    }
  }

  var text = buf.toString();
  if (text.isEmpty) return '';

  // Aplica formatação innermost-first → outermost
  if (color != null && color.length == 6) {
    text = '<span style="color:#$color">$text</span>';
  }
  if (isSubscript) text = '<sub>$text</sub>';
  if (isSuperscript) text = '<sup>$text</sup>';
  if (isStrike) text = '<s>$text</s>';
  if (isUnderline) text = '<u>$text</u>';
  if (isItalic) text = '<em>$text</em>';
  if (isBold) text = '<strong>$text</strong>';

  return text;
}

/// Escape HTML entities pra não quebrar a marcação.
String _escHtml(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

// ── Render: junta os parágrafos + aninha listas ─────────────────────────

String _renderHtml(List<_ParaDesc> descritores) {
  final buf = StringBuffer();
  final listStack = <_ListFrame>[]; // pilha de listas abertas

  void fecharListasAte(int targetLevel, {bool fechaTudo = false}) {
    while (listStack.isNotEmpty &&
        (fechaTudo || listStack.last.level > targetLevel)) {
      final f = listStack.removeLast();
      buf.write(f.isNumbered ? '</ol>' : '</ul>');
    }
  }

  for (final d in descritores) {
    if (d.isList) {
      // Abre/ajusta listas até o nivel desejado
      while (listStack.isNotEmpty && listStack.last.level > d.listLevel) {
        fecharListasAte(d.listLevel);
      }
      // Se mudou de tipo no mesmo nível, fecha e reabre
      if (listStack.isNotEmpty &&
          listStack.last.level == d.listLevel &&
          listStack.last.isNumbered != d.isNumbered) {
        fecharListasAte(d.listLevel - 1);
      }
      // Abre lista nova se precisar
      while (listStack.isEmpty || listStack.last.level < d.listLevel) {
        final newLevel = listStack.isEmpty ? 0 : listStack.last.level + 1;
        if (newLevel > d.listLevel) break;
        buf.write(d.isNumbered ? '<ol>' : '<ul>');
        listStack.add(_ListFrame(level: newLevel, isNumbered: d.isNumbered));
      }
      buf.write('<li>${d.inlineHtml}</li>');
      continue;
    }

    // Não é lista — fecha qualquer lista aberta
    if (listStack.isNotEmpty) fecharListasAte(0, fechaTudo: true);

    // Heading
    if (d.headingLevel != null) {
      final h = d.headingLevel!;
      final styles = _montaCssStyle(d);
      final attr = styles.isEmpty ? '' : ' style="$styles"';
      buf.write('<h$h$attr>${_prefixoIndent(d)}${d.inlineHtml}</h$h>');
      continue;
    }

    // Parágrafo vazio → quebra visual extra
    if (d.inlineHtml.isEmpty) {
      buf.write('<p>&nbsp;</p>');
      continue;
    }

    // Parágrafo normal
    final styles = _montaCssStyle(d);
    final attr = styles.isEmpty ? '' : ' style="$styles"';
    buf.write('<p$attr>${_prefixoIndent(d)}${d.inlineHtml}</p>');
  }

  // Fecha qualquer lista pendente
  fecharListasAte(0, fechaTudo: true);

  return buf.toString();
}

class _ListFrame {
  final int level;
  final bool isNumbered;
  const _ListFrame({required this.level, required this.isNumbered});
}

/// Monta o atributo `style` inline com alinhamento apenas.
/// margin-left/padding-left são ignorados pelo flutter_html v3 em elementos
/// de bloco — a indentação esquerda é tratada via prefixo em `_prefixoIndent`.
String _montaCssStyle(_ParaDesc d) {
  final partes = <String>[];
  if (d.align != null) partes.add('text-align:${d.align}');
  return partes.join(';');
}

/// Retorna prefixo de espaços-em (`&emsp;`) para simular indentação.
/// Combina marginLeft (indentação de bloco) + textIndent (primeira linha).
/// flutter_html não renderiza `text-indent` nem `padding-left` em blocos —
/// usar texto inline garante o efeito visual. 1 em-space ≈ 24 px.
String _prefixoIndent(_ParaDesc d) {
  double totalPx = 0;
  if (d.marginLeftPx != null && d.marginLeftPx! > 0) {
    totalPx += d.marginLeftPx!;
  }
  if (d.textIndentPx != null && d.textIndentPx! > 0) {
    totalPx += d.textIndentPx!;
  }
  if (totalPx <= 0) return '';
  final qtd = (totalPx / 24).round().clamp(1, 8);
  return '&emsp;' * qtd;
}

// ─────────────────────────────────────────────────────────────────────────────
// PDF → HTML (texto plano envolvido em parágrafos)
// PDF não preserva formatação rich de forma confiável; fazemos limpeza
// agressiva (diacríticos colados, hifens com espaço) + detecção heurística
// de parágrafos.
// ─────────────────────────────────────────────────────────────────────────────

Future<ExtractedText> extractPdfToHtml(String path) async {
  final bytes = await File(path).readAsBytes();
  final document = PdfDocument(inputBytes: bytes);

  try {
    final extractor = PdfTextExtractor(document);
    final raw = extractor.extractText(layoutText: true);
    final paragrafos = _extrairParagrafosPdf(raw);
    final html = paragrafos
        .map((p) => '<p>${_escHtml(p)}</p>')
        .join();
    return ExtractedText(html: html, hasFormatting: false);
  } finally {
    document.dispose();
  }
}

List<String> _extrairParagrafosPdf(String raw) {
  // 1. Diacríticos colados (Buddha ṃ → Buddhaṃ)
  const diacriticosColados = 'ṃḥṅñṇṭḍśṣṛṝḷḹṁ';
  var s = raw.replaceAllMapped(
    RegExp('([A-Za-zĀāĪīŪūṚṛ])\\s+([$diacriticosColados])'),
        (m) => '${m[1]}${m[2]}',
  );

  // 2. Hifens com espaços ao redor
  s = s.replaceAll(RegExp(r'\s+-\s+'), '-');

  // 3. Normaliza espaços horizontais
  s = s.replaceAll(RegExp(r'[ \t]+'), ' ');

  // 4. Detecta parágrafos
  final linhas = s.split('\n').map((l) => l.trim()).toList();
  final paragrafos = <String>[];
  final buf = StringBuffer();

  for (final atual in linhas) {
    if (atual.isEmpty) {
      if (buf.isNotEmpty) {
        paragrafos.add(buf.toString().trim());
        buf.clear();
      }
      continue;
    }

    if (buf.isEmpty) {
      buf.write(atual);
    } else {
      final anterior = buf.toString().trimRight();
      final terminaFrase = RegExp(r'[\.\|\?!:]$').hasMatch(anterior);
      final comecaMaiuscula =
      RegExp(r'^[A-ZÁÉÍÓÚÂÊÎÔÛÃÕÀÄËÏÖÜĀĪŪṚṢŚṆṂ"“]').hasMatch(atual);

      if (terminaFrase && comecaMaiuscula) {
        paragrafos.add(anterior);
        buf.clear();
        buf.write(atual);
      } else {
        buf.write(' $atual');
      }
    }
  }
  if (buf.isNotEmpty) paragrafos.add(buf.toString().trim());

  return paragrafos.where((p) => p.isNotEmpty).toList();
}

/// .txt → HTML simples (cada linha em branco = parágrafo novo).
String _plainTextToHtml(String txt) {
  return txt
      .split(RegExp(r'\n\s*\n+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .map((p) => '<p>${_escHtml(p).replaceAll('\n', '<br>')}</p>')
      .join();
}