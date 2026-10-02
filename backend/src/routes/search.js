const express = require('express')
const router = express.Router()
const { PrismaClient } = require('@prisma/client')
const Fuse = require('fuse.js')
const { toPage, toLimit } = require('../utils/sanitize')
const { loadModelIndex, cardShape } = require('../utils/productShape')
const prisma = new PrismaClient()

//ตัดคำภาษาไทย
const segmenter = new Intl.Segmenter('th', { granularity: 'word' })
//คำเชื่อม
const fillers = new Set([
  'ที่', 'มี', 'กับ', 'และ', 'ซึ่ง', 'แบบ', 'พร้อม', 'รองรับ', 'อยาก', 'ได้',
  'ต้องการ', 'ช่วย', 'หา', 'แนะนำ', 'สินค้า', 'ระบบ',
  'with', 'has', 'and', 'that', 'which', 'product', 'products',
])

//Keyboard Layout Mapping — กู้คำค้นที่พิมพ์ผิดแป้น
const KEDMANEE_ROWS = [
  // แถวตัวเลข
  ['1234567890-=', 'ๅ/_ภถุึคตจขช'],
  ['!@#$%^&*()_+', '+๑๒๓๔ู฿๕๖๗๘๙'],
  // แถวบน
  ['qwertyuiop[]', 'ๆไำพะัีรนยบล'],
  ['QWERTYUIOP{}', '๐"ฎฑธํ๊ณฯญฐ,'],
  // แถวกลาง
  ["asdfghjkl;'", 'ฟหกดเ้่าสวง'],
  ['ASDFGHJKL:"', 'ฤฆฏโฌ็๋ษศซ.'],
  // แถวล่าง
  ['zxcvbnm,./', 'ผปแอิืทมใฝ'],
  ['ZXCVBNM<>?', '()ฉฮฺ์?ฒฬฦ'],
]
//เก็บค่าแป้นพิมพ์
const THAI_BY_LATIN = new Map()
const LATIN_BY_THAI = new Map()

//แตกตารางเป็น Map สองทิศทาง ทำครั้งเดียวตอนโหลดไฟล์ แล้วใช้ตลอดอายุเซิร์ฟเวอร์
for (const [latin, thai] of KEDMANEE_ROWS) {
  for (let i = 0; i < latin.length; i++) {
    // คีย์เป็นอังกฤษ ค่าเป็นไทย = ใช้ตอนผู้ใช้พิมพ์ "อังกฤษเยอะกว่า" แล้วต้องแปลงเป็นไทย
    if (!THAI_BY_LATIN.has(latin[i])) THAI_BY_LATIN.set(latin[i], thai[i])
    // คีย์เป็นไทย ค่าเป็นอังกฤษ = ใช้ตอนผู้ใช้พิมพ์ "ไทยเยอะกว่า" แล้วต้องแปลงเป็นอังกฤษ
    if (!LATIN_BY_THAI.has(thai[i])) LATIN_BY_THAI.set(thai[i], latin[i])
  }
}

//แปลงข้อความทั้งก้อนข้ามแป้น
function swapKeyboardLayout(text) {
  const source = String(text)
  const thaiCount = (source.match(/[฀-๿]/g) || []).length
  const latinCount = (source.match(/[a-zA-Z]/g) || []).length
  if (thaiCount === 0 && latinCount === 0) return ''
  const table = thaiCount > latinCount ? LATIN_BY_THAI : THAI_BY_LATIN
  let out = ''
  let converted = 0
  for (const ch of source) {
    const mapped = table.get(ch)
    if (mapped === undefined) { out += ch; continue }
    out += mapped
    converted++
  }
  //ไม่มีอะไรแปลงได้เลย = ไม่ใช่เคสพิมพ์ผิดแป้น ถือว่าไม่มีคำเดา
  return converted > 0 ? out : ''
}

//Shift-layer Mapping — กู้คำค้นไทยที่พิมพ์ตอนเปิด Caps Lock (หรือกด Shift ค้าง)
const SHIFT_TOGGLE = new Map()
const THAI_UPPER = new Set()
for (let row = 0; row < KEDMANEE_ROWS.length; row += 2) {
  const lower = KEDMANEE_ROWS[row][1]
  const upper = KEDMANEE_ROWS[row + 1][1]
  for (let i = 0; i < lower.length; i++) {
    SHIFT_TOGGLE.set(lower[i], upper[i])
    SHIFT_TOGGLE.set(upper[i], lower[i])
    THAI_UPPER.add(upper[i])
  }
}
// เครื่องหมายชั้นบนที่คนพิมพ์ปกติก็ต้องกด Shift อยู่แล้ว (์ ๊ ๋ ็) — ตัวเดียวกันอาจเป็น
// "ตั้งใจพิมพ์ตัวนี้จริง" หรือ "ติด Shift มาจากตัวชั้นล่าง" ก็ได้ ตัดสินจากตัวอักษรเดียวไม่ได้
// ในตัวอย่างข้างบน ็ ต้องสลับเป็น ้ แต่ ์ ตัวท้ายต้องคงไว้ จึงต้องลองทั้งสองแบบ
const AMBIGUOUS_MARKS = new Set(['็', '๊', '๋', '์'])
// ลองสลับ/ไม่สลับเครื่องหมายได้ไม่เกินกี่ตำแหน่ง — 3 ตำแหน่ง = คำเดาสูงสุด 8 แบบ
const MAX_AMBIGUOUS_MARKS = 3

// คืนรายการคำเดา เรียงจากน่าจะเป็นมากไปน้อย (ว่าง = ไม่ใช่เคสติด Shift)
function toggleThaiShift(text) {
  const source = String(text)
  let upper = 0
  let lower = 0
  for (const ch of source) {
    if (!SHIFT_TOGGLE.has(ch) || ch < '฀' || AMBIGUOUS_MARKS.has(ch)) continue
    if (THAI_UPPER.has(ch)) upper++
    else lower++
  }
  if (upper === 0 || upper <= lower) return []

  const chars = [...source]
  const toggled = chars.map((ch) => SHIFT_TOGGLE.get(ch) ?? ch)
  const ambiguous = chars
    .map((ch, i) => (AMBIGUOUS_MARKS.has(ch) ? i : -1))
    .filter((i) => i >= 0)
    .slice(0, MAX_AMBIGUOUS_MARKS)
  // bit ที่เป็น 1 = คงเครื่องหมายตำแหน่งนั้นไว้ตามที่พิมพ์ · เริ่มจาก 0 (สลับทุกตัว = แบบ
  // Caps Lock ล้วน) แล้วค่อยคงไว้ทีละมากขึ้น
  const masks = [...Array(1 << ambiguous.length).keys()]
    .sort((a, b) => bitCount(a) - bitCount(b) || a - b)
  const candidates = masks.map((mask) => {
    const out = [...toggled]
    ambiguous.forEach((pos, bit) => { if (mask & (1 << bit)) out[pos] = chars[pos] })
    return out.join('')
  })
  return [...new Set(candidates)].filter((candidate) => candidate !== source)
}

function bitCount(n) {
  let count = 0
  for (; n; n >>= 1) count += n & 1
  return count
}

// Normalization — ทำให้คำที่เขียนต่างกันแต่หมายถึงสิ่งเดียวกันเทียบกันได้ก่อนทุกขั้นตอน
function normalize(value) {
  return String(value ?? '').normalize('NFKC').toLowerCase().trim()
    .replace(/wi[\s-]+fi/g, 'wifi')
    .replace(/dash[\s-]+cam/g, 'dashcam')
}

// Tokenization + Thai Word Segmentation — หัวใจของการค้นภาษาไทยที่ไม่มีช่องว่างระหว่างคำ
// ใช้ Intl.Segmenter ที่ติดมากับ Node เอง ไม่ต้องลงไลบรารีตัดคำเพิ่ม
function words(value) {
  // Separate scripts first: Intl alone can keep "มีGPSกับAI" together.
  return (normalize(value).match(/[a-z0-9]+|[\u0e00-\u0e7f]+/g) || [])
    .flatMap((run) => /[\u0e00-\u0e7f]/.test(run)
      ? [...segmenter.segment(run)].filter((part) => part.isWordLike).map((part) => part.segment)
      : [run])
}

// Stopword Removal — ตัดคำเชื่อมออกจาก "คำค้น" เท่านั้น ไม่ตัดจากข้อมูลสินค้า
function queryWords(value) {
  return [...new Set(words(value).filter((word) => !fillers.has(word)))]
}
//คำพ้องความหมาย
const synonymGroups = [
  ['dashcam', 'กล้องติดรถยนต์', 'กล้องติดหน้ารถ'],
  ['camera', 'กล้อง'],
].map((group) => group.map(words))

// Synonym Expansion — ขยายคำพ้องฝั่งข้อมูลสินค้าตอน index
function indexedWords(value) {
  const tokens = words(value)
  const expanded = new Set(tokens)
  for (const group of synonymGroups) {
    // Require a complete, consecutive phrase within one field. A generic camera
    // or an unrelated mention of a car must not become a dashcam.
    if (group.some((phrase) => tokens.some((_, start) =>
      phrase.every((word, offset) => tokens[start + offset] === word)))) {
      for (const phrase of group) for (const word of phrase) expanded.add(word)
    }
  }
  return [...expanded]
}


//กำหนดขอบเขตการค้นหา
function editBudget(term, lenient = false) {
  return (term.length >= 8 ? 2 : 1) + (lenient ? 1 : 0)
}

// Fuzzy Search (ตัวคุม) — คำแบบไหน "ห้ามเดา" เด็ดขาด — ตัวย่อสั้น (AI/4G), คำที่มีตัวเลขปนซึ่งมักเป็นรหัสรุ่น
// (4G ต้องไม่กลายเป็น 5G), และคำยาวผิดปกติที่คำนวณแล้วไม่คุ้ม
function fuzzyAllowed(term) {
  return term.length >= 4 && term.length <= 64 && !/\d/.test(term)
}

// Fuzzy Search (transposition) — ส่วนที่ fuse.js ทำแทนไม่ได้
// สองคำนี้ต่างกันแค่ "สลับอักษรคู่ที่ติดกัน" หนึ่งครั้งหรือเปล่า (trakcing → tracking,
// GSP → GPS) — พิมพ์รัวจนสลับตัวเป็นความผิดพลาดที่พบบ่อยที่สุดแบบหนึ่ง แต่ Bitap
// ที่ fuse ใช้ไม่มีปฏิบัติการนี้ มันนับการสลับ 1 คู่เป็นพิมพ์ผิด 2 ตัว ทำให้คำสั้น
// (โควตาผิดได้ 1 ตัว) หลุดตะแกรงไปทั้งที่ผู้ใช้แค่พิมพ์สลับ จึงต้องดักเองก่อนถึง fuse
// CBA → ABC ไม่นับ เพราะสลับตัวหัวกับตัวท้ายไม่ใช่อาการพิมพ์รัว
function isAdjacentSwap(a, b) {
  if (a.length !== b.length) return false
  let i = 0
  while (i < a.length && a[i] === b[i]) i++
  if (i >= a.length - 1) return false
  if (a[i] !== b[i + 1] || a[i + 1] !== b[i]) return false
  return a.slice(i + 2) === b.slice(i + 2)
}

// ★ ศูนย์รวมการจับคู่คำ — Exact Search / Prefix Search / Fuzzy Search อยู่ในนี้ทั้งหมด
// คิดคะแนน "คำที่พิมพ์ → คำในคลัง" ครั้งเดียวต่อหนึ่งคำค้น แล้วเอาไปใช้ซ้ำกับสินค้าทุกตัว
function scoreTermAgainstVocabulary(term, vocabulary, { prefix = false, prefixMin = 4, lenient = false } = {}) {
  const scores = new Map()

  //Exact Search
  if (vocabulary.has(term)) scores.set(term, 1)

  // Prefix Search — เปิดเฉพาะคำสุดท้ายตอน autocomplete (ผู้ใช้ยังพิมพ์ไม่จบ)
  // ต้องยาวพอ ไม่งั้น "ad" ลากสินค้ามาทั้งเว็บ — ค่าเริ่มต้น 4 (รอบ "คุณหมายถึง…?")
  // ช่อง autocomplete ส่ง prefixMin = 2 มาเอง เพราะตัดเหลือไม่กี่รายการที่คะแนนสูงสุดอยู่แล้ว
  if (prefix && term.length >= prefixMin) {
    for (const token of vocabulary) {
      if (token !== term && token.startsWith(term)) {
        scores.set(token, Math.max(scores.get(token) ?? 0, 0.9))
      }
    }
  }

  // Fuzzy Search (transposition) — พิมพ์สลับอักษรติดกัน คิดเป็นพิมพ์ผิด 1 ตัวเท่านั้น
  // (ดู isAdjacentSwap)
  // ตัวย่อ 3 ตัวอักษรได้รับการยกเว้นให้เดาได้ ทั้งที่สั้นกว่าเกณฑ์ fuzzy ปกติ
  // เพราะ GSP/GPS เดาผิดยาก ต่างจากคำ 3 ตัวอักษรทั่วไปที่สลับแล้วกลายเป็นคนละคำ
  const shortAcronym = /^[a-z]{3}$/.test(term)
  if (shortAcronym || fuzzyAllowed(term)) {
    for (const token of vocabulary) {
      if (token === term || !isAdjacentSwap(term, token)) continue
      if (shortAcronym ? !/^[a-z]{3}$/.test(token) : /\d/.test(token)) continue
      scores.set(token, Math.max(scores.get(token) ?? 0, 1 - 1 / term.length))
    }
  }

  // Fuzzy Search (fuse.js) — คำที่พิมพ์ผิดแบบทั่วไป
  if (fuzzyAllowed(term)) {
    const budget = editBudget(term, lenient)
    // คำที่ยาวต่างกันเกินโควตาตัดทิ้งก่อน ไม่ต้องส่งให้ fuse เลย — เป็นด่านที่กัน
    // Bitap จับ pattern สั้นกลางคำยาว (`track` ใน `tracking`) ซึ่งเป็นพฤติกรรม
    // ที่ผิดสำหรับการค้นชื่อสินค้า และตัดขนาดงานของ fuse ลงมากด้วย
    const candidates = []
    for (const token of vocabulary) {
      if (/\d/.test(token)) continue
      if (Math.abs(term.length - token.length) > budget) continue
      candidates.push(token)
    }
    if (candidates.length > 0) {
      // threshold = สัดส่วนความผิดพลาดสูงสุดที่ยอมรับ (จำนวนตัวที่ผิด ÷ ความยาวคำ)
      // ให้ค่าตรงกับ "โควตา" ด้านบน
      //
      // location: 0 + distance เท่ากับความยาวคำ = บังคับให้แมตช์ "เริ่มที่ต้นคำ"
      // โดยคิดค่าเยื้องตำแหน่ง 1 ตัวอักษรเท่ากับพิมพ์ผิด 1 ตัว — จำเป็นมาก เพราะ
      // Bitap มองหา pattern เป็น "ส่วนหนึ่งของข้อความ" ไม่ใช่ทั้งคำ ถ้าปล่อยไว้
      // (ignoreLocation) คำว่า adas จะไปตรงกับ waas ได้ฟรี (ตัด d เหลือ aas ซึ่ง
      // ซ่อนอยู่กลางคำ waas = ผิดแค่ 1 ในสายตา Bitap ทั้งที่จริงต่างกัน 2 ตัว)
      const fuse = new Fuse(candidates, {
        includeScore: true,
        threshold: Math.min(1, budget / term.length),
        location: 0,
        distance: term.length,
        minMatchCharLength: 1,
        shouldSort: false,
      })
      for (const hit of fuse.search(term)) {
        // fuse ให้ 0 = เหมือนเป๊ะ, 1 = ไกลสุด — พลิกเป็น "ความใกล้เคียง" ให้ทิศทาง
        // เดียวกับคะแนนระดับอื่น แล้วกันไม่ให้ทับคะแนนที่มั่นใจกว่า (ตรงเป๊ะ/ขึ้นต้น)
        const similarity = 1 - (hit.score ?? 1)
        scores.set(hit.item, Math.max(scores.get(hit.item) ?? 0, similarity))
      }
    }
  }

  return scores
}

// Field Weighting — ชื่อ/รหัส/แท็กคือตัวตนของสินค้า ค่าสเปคเป็นข้อมูลประกอบ
function itemFields(item) {
  return [
    [item.itm_desc, 1], [item.itm_sku, 1], [item.itm_tags, 1],
    [item.item_type?.itm_type_desc, 0.95],
    ...(item.attribute_values || []).map((entry) => [entry.value, 0.8]),
  ].map(([value, weight]) => ({ tokens: indexedWords(value), weight }))
}

// IDF (ครึ่งหนึ่งของ TF-IDF / BM25) — คำที่หายากบอกตัวตนสินค้าได้ดีกว่าคำที่มีอยู่ทั่วไป
//
// ปัญหาเดิม: ทุกคำในคำค้นน้ำหนักเท่ากันหมด ค้น "GPS DTRACK" แล้วคำว่า GPS ซึ่งมี
// อยู่ในสินค้าเกือบทุกตัว ถ่วงคะแนนเท่ากับ DTRACK ที่มีไม่กี่ตัว สินค้าที่ตรงคำหายาก
// จึงไม่ได้เปรียบอย่างที่ควร
//
// สูตรนี้คือ idf ของ BM25 (มี +0.5 กันหารศูนย์ และ 1+ กันค่าติดลบตอนคำโผล่เกือบทุกตัว)
// ส่วนอีกสองชิ้นของ BM25 จงใจไม่เอามา:
//   • tf saturation — ที่นี่ "tf" ไม่ใช่จำนวนครั้งที่คำโผล่ แต่เป็นคุณภาพการจับคู่ 0–1
//     (ตรงเป๊ะ/ขึ้นต้น/พิมพ์ผิด) ซึ่งอิ่มตัวอยู่แล้วโดยธรรมชาติ
//   • document length normalization — จะไปลงโทษสินค้าที่กรอกสเปคละเอียด ทั้งที่
//     สเปคละเอียดแปลว่าข้อมูลครบ ไม่ได้แปลว่าตรงคำค้นน้อยลง
function inverseDocumentFrequency(docFreq, totalDocs) {
  return Math.log(1 + (totalDocs - docFreq + 0.5) / (docFreq + 0.5))
}

// ★ Boolean AND + Exact Search (ชื่อเต็ม) + Relevance Ranking + IDF weighting
// ท่อหลักที่ประกอบทุกชั้นเข้าด้วยกัน — หน้าผลค้นหากับ autocomplete ใช้ตัวเดียวกัน
// ต่างกันแค่ธง `autocomplete` ที่เปิด Prefix Search ให้คำสุดท้าย
// `requireAll` = ต้องตรงครบทุกคำไหม
//   true  (ค่าเริ่มต้น) — ผลค้นหาจริงและ autocomplete ใช้ Boolean AND เต็มรูปเหมือนเดิม
//   false — ใช้เฉพาะรอบหา "คุณหมายถึง…?" ผ่อนเป็น "ต้องตรงอย่างน้อยครึ่งหนึ่งของคำ"
//           เพราะรอบนั้นเกิดขึ้นตอนค้นไม่เจอแล้ว การไปบังคับให้ตรงครบทุกคำอีกครั้ง
//           ก็ไม่เหลืออะไรให้แนะนำ (คำที่ทำให้ค้นไม่เจอยังได้ 0 เหมือนเดิมอยู่ดี)
function searchProducts(items, query, { autocomplete = false, prefixMin = 4, requireAll = true, lenient = false } = {}) {
  const terms = queryWords(query)
  if (!terms.length) return []

  // เกณฑ์ขั้นต่ำของจำนวนคำที่ต้องตรง — ครึ่งหนึ่งคือเส้นแบ่งที่ยังพอบอกได้ว่า
  // "ผู้ใช้น่าจะหมายถึงตัวนี้" ถ้าปล่อยให้ตรงคำเดียวก็พอ พิมพ์มั่วจะมีสินค้าโผล่มา
  // แนะนำมั่วๆ ซึ่งแย่กว่าไม่แนะนำอะไรเลย · คำค้นคำเดียวได้ค่าเท่ากับ AND พอดี
  // (ceil(1/2) = 1) พฤติกรรมจึงไม่เปลี่ยน
  const minMatches = requireAll ? terms.length : Math.max(1, Math.ceil(terms.length / 2))

  // แตกคำของสินค้าทุกตัวรอบเดียว แล้วรวมเป็น "คลังคำ" ให้ fuse ค้นทีเดียวต่อคำค้น
  const fieldsByItem = items.map(itemFields)
  const vocabulary = new Set()
  for (const fields of fieldsByItem) for (const field of fields) for (const token of field.tokens) vocabulary.add(token)

  const scoreTables = terms.map((term, index) =>
    scoreTermAgainstVocabulary(term, vocabulary, {
      prefix: autocomplete && index === terms.length - 1,
      prefixMin,
      lenient,
    })
  )

  // คิดคะแนนรายคำของสินค้าทุกตัวก่อน เพราะต้องรู้ว่าแต่ละคำ "พบในสินค้ากี่ตัว"
  // (document frequency) ถึงจะคำนวณ IDF ได้ — ทำในรอบเดียวไม่ต้องวนซ้ำ
  const scoresByItem = items.map((_, itemIndex) => {
    const fields = fieldsByItem[itemIndex]
    return scoreTables.map((table) => {
      let score = 0
      for (const field of fields) {
        for (const token of field.tokens) {
          const matched = table.get(token)
          if (matched !== undefined) score = Math.max(score, matched * field.weight)
        }
      }
      return score
    })
  })

  const termWeights = terms.map((_, termIndex) => {
    const docFreq = scoresByItem.reduce((count, scores) => count + (scores[termIndex] > 0 ? 1 : 0), 0)
    return inverseDocumentFrequency(docFreq, items.length)
  })
  const totalWeight = termWeights.reduce((a, b) => a + b, 0)

  const ranked = []
  items.forEach((item, itemIndex) => {
    const scores = scoresByItem[itemIndex]
    // AND applies even when a word is misspelled; never fall back to a partial OR.
    // (requireAll: true ทำให้ minMatches = จำนวนคำทั้งหมด เงื่อนไขนี้จึงเท่ากับ
    //  "ห้ามมีคำไหนได้ 0" แบบเดิมเป๊ะ — ผลค้นหาหลักไม่เปลี่ยนพฤติกรรม)
    const matchedTerms = scores.reduce((count, score) => count + (score > 0 ? 1 : 0), 0)
    if (matchedTerms < minMatches) return
    const exactName = normalize(item.itm_desc) === normalize(query)
    // ค่าเฉลี่ยแบบถ่วงน้ำหนักด้วย IDF — ยังอยู่ในช่วง 0–1 เหมือนเดิม เพราะหารด้วย
    // ผลรวมน้ำหนัก (คำค้นคำเดียวจึงได้คะแนนเท่าเดิมเป๊ะ ไม่ว่าคำนั้นจะหายากแค่ไหน)
    const weighted = scores.reduce((sum, score, termIndex) => sum + score * termWeights[termIndex], 0) / totalWeight
    ranked.push({
      item,
      relevance_score: exactName ? 1 : weighted,
      matched_words: scores.filter((score) => score >= 0.8).length,
      exact_term: exactName,
    })
  })

  return ranked.sort((a, b) => Number(b.exact_term) - Number(a.exact_term)
    || b.relevance_score - a.relevance_score
    || String(a.item.itm_code).localeCompare(String(b.item.itm_code)))
}

// Faceted Filter + Sort + Pagination + Did-You-Mean
// ชั้นนี้ไม่ได้จับคู่คำเอง — กรองสินค้าก่อน แล้วส่งต่อให้ searchProducts() จัดอันดับ
router.get('/', async (req, res) => {
  try {
    const {
      searchword = '',
      category_id,
      category_ids,
      tags,
      min_price,
      max_price,
      sort = 'relevance',
    } = req.query
    // บังคับช่วงหน้า/จำนวนต่อหน้าให้อยู่ในค่าที่รับได้เสมอ (ดู utils/sanitize.js)
    const page = toPage(req.query.page)
    const limit = toLimit(req.query.limit, 20, 100)
    //คำนวณหน้า (page) ให้เป็นลำดับ (offset)
    const offset = (page - 1) * limit
    //ตัดช่องว่างหน้าหลังและแปลงเป็นตัวพิมพ์เล็ก
    const searchTerm = String(searchword).trim()

    if (!searchTerm) {
      return res.json({ products: [], total: 0, page: 1, suggestions: [] })
    }
    //เงื่อนไขการค้นหา
    const where = { itm_flag: '1' }
    // ตัวกรองแบบติ๊กหลายรายการ — กติกาเดียวกับ GET /api/products (ดูคอมเมนต์ที่นั่น):
    // หลายหมวดหมู่ = "หรือ", แต่ละคุณสมบัติที่ติ๊ก = เงื่อนไข "และ" เพิ่มอีกชั้น
    const csv = (value) => String(value ?? '').split(',').map((s) => s.trim()).filter(Boolean)
    const categoryCodes = category_ids ? csv(category_ids) : (category_id ? [String(category_id)] : [])
    if (categoryCodes.length === 1) where.itm_type_code = categoryCodes[0]
    else if (categoryCodes.length > 1) where.itm_type_code = { in: categoryCodes }
    // Wildcard (ILIKE) — ที่เดียวในระบบที่ค้นในชั้น DB และเป็นแค่ตัวกรองหยาบ
    // แท็กเก็บเป็นข้อความคอมม่าคั่น — narrow ด้วย contains แล้วกรองให้ตรงทั้งคำ
    // อีกชั้นตอนคัดผลลัพธ์ด้านล่าง (กัน "AI" ไปแมตช์คำที่มี ai อยู่ข้างใน)
    const wantedTags = csv(tags)
    if (wantedTags.length > 0) {
      where.AND = wantedTags.map((tag) => ({ itm_tags: { contains: tag, mode: 'insensitive' } }))
    }
    if (min_price) where.itm_price = { ...(where.itm_price || {}), gte: Number(min_price) }
    if (max_price) where.itm_price = { ...(where.itm_price || {}), lte: Number(max_price) }
    //ดึงข้อมูลสินค้าทั้งหมดจากฐานข้อมูล
    const candidateRows = await prisma.tbl_item.findMany({
      where,
      include: { item_type: true, attribute_values: { include: { attribute: true } } },
    })
    // Exact Search (แท็ก) — contains ด้านบนแค่กรองหยาบ ตรงนี้เช็คให้ตรงทั้งคำจริงๆ
    const hasTag = (item, tag) =>
      String(item.itm_tags ?? '').split(',').map((t) => t.trim().toLowerCase()).includes(tag.toLowerCase())
    const candidates = wantedTags.length === 0
      ? candidateRows
      : candidateRows.filter((item) => wantedTags.every((tag) => hasTag(item, tag)))
    // ดึงโมเดลของผู้เข้าชิงทั้งหมดครั้งเดียว แล้วใช้ดัชนีเดียวกันตลอดทั้ง request
    // (toResults ถูกเรียกซ้ำได้ถึง 5 รอบตอนกู้คำที่พิมพ์ผิดแป้น ถ้าไปยิง DB ในนั้น
    // จะกลายเป็นหลายสิบคำสั่งต่อการค้นหาหนึ่งครั้ง)
    const modelIndex = await loadModelIndex(candidates, prisma)
    const toResults = (term) => searchProducts(candidates, term).map(({ item, ...match }) => ({
      ...cardShape(item, modelIndex),
      ...match,
    }))

    // คำนี้ "ใช้ได้" หรือยัง — ใช้ตัดสินว่าต้องกู้แป้นพิมพ์ให้คำนี้ไหม
    // สองเงื่อนไข เพราะคำที่ใช้ได้มีสองแบบ:
    //   1. ค้นแล้วเจอสินค้าจริง
    //   2. เป็นคำเชื่อมล้วน (queryWords ตัดทิ้งหมดจนเหลือศูนย์คำ) เช่น "สินค้าที่มี"
    //      แบบนี้ค้นยังไงก็ได้ศูนย์รายการ แต่ไม่ได้แปลว่าพิมพ์ผิด — ถ้าไม่ดักไว้
    //      จะไปแปลงคำไทยที่ถูกต้องอยู่แล้วให้กลายเป็นขยะ
    const usableToken = (token) => queryWords(token).length === 0 || toResults(token).length > 0

    // Keyboard Layout Mapping (รายคำ) — เผื่อผู้ใช้สลับแป้นกลางประโยคแล้วสลับผิดคนละทิศ
    // เช่น "lbo8hkmuj,u ไรดร" ที่ตั้งใจพิมพ์ "สินค้าที่มี wifi" — คำแรกพิมพ์ไทยตอนแป้น
    // เป็นอังกฤษ คำหลังพิมพ์อังกฤษตอนแป้นเป็นไทย
    //
    // แปลงทั้งก้อนทิศเดียวแก้เคสนี้ไม่ได้ เพราะ swapKeyboardLayout() เลือกทิศจากการนับ
    // อักษรทั้งข้อความ ได้ทิศเดียวเสมอ อีกครึ่งจึงถูกปล่อยผ่านไปทั้งที่ผิด
    const MAX_RECOVER_TOKENS = 6
    function recoverPerToken(term) {
      // split แบบเก็บตัวคั่นไว้ด้วย จะได้ประกอบกลับโดยช่องว่างเดิมไม่เพี้ยน
      const chunks = term.split(/(\s+)/)
      if (chunks.filter((chunk) => chunk.trim()).length > MAX_RECOVER_TOKENS) return ''
      let changed = false
      const recovered = chunks.map((chunk) => {
        if (!chunk.trim() || usableToken(chunk)) return chunk
        const swapped = swapKeyboardLayout(chunk)
        if (!swapped || swapped === chunk || !usableToken(swapped)) return chunk
        changed = true
        return swapped
      })
      return changed ? recovered.join('') : ''
    }

    let results = toResults(searchTerm)
    // คำที่ใช้หา suggestions ต่อ — ถ้ากู้แป้นพิมพ์สำเร็จต้องใช้คำที่แปลงแล้ว ไม่ใช่คำดิบ
    let effectiveTerm = searchTerm
    // Keyboard Layout Mapping — ลองก็ต่อเมื่อ "ไม่เจออะไรเลย" เท่านั้น
    // ถ้าคำค้นเจอสินค้าอยู่แล้วแปลว่าผู้ใช้พิมพ์ถูกแป้น ไม่ต้องไปเดาแทนเขา
    //
    // ลองทั้งก้อนก่อนเสมอ (เคสที่พบบ่อยสุด ราคาถูกสุด แค่ค้นเพิ่มครั้งเดียว) แล้วค่อย
    // ตกมารายคำซึ่งต้องค้นเพิ่มสูงสุด 2 ครั้งต่อคำ — ยอมจ่ายได้เพราะเส้นทางนี้เดินเฉพาะ
    // ตอนผู้ใช้กำลังจะเห็น "ไม่พบสินค้า" อยู่แล้ว
    let searched_as = null
    if (results.length === 0) {
      // ลำดับ: สลับภาษาทั้งก้อน → สลับภาษารายคำ → สลับชั้น Shift (Caps Lock ค้าง)
      const guesses = [swapKeyboardLayout(searchTerm), recoverPerToken(searchTerm), ...toggleThaiShift(searchTerm)]
      for (const candidate of guesses) {
        if (!candidate || candidate === searchTerm) continue
        const retry = toResults(candidate)
        // ยอมรับคำที่แปลงแล้วต่อเมื่อมันหาเจอจริง — ไม่งั้นปล่อยให้ขึ้น "ไม่พบสินค้า"
        // พร้อม "คุณหมายถึง…?" ของคำเดิมตามปกติ ดีกว่าโชว์คำแปลกๆ ที่ก็หาไม่เจอเหมือนกัน
        if (retry.length === 0) continue
        results = retry
        effectiveTerm = candidate
        searched_as = candidate
        break
      }
    }

    const sortFns = {
      // Exact product names first, followed by aggregate per-word relevance.
      relevance: (a, b) =>
        Number(b.exact_term) - Number(a.exact_term) ||
        (b.relevance_score || 0) - (a.relevance_score || 0),
      // สินค้าที่ไม่ได้ตั้งราคา (แสดงว่า "ราคาติดต่อสอบถาม") ไปท้ายสุดเสมอ
      // ทั้งสองทิศทาง ไม่ใช่มากองหัวแถวตอนเรียงน้อย→มาก
      price_asc: (a, b) =>
        Number(!Number(a.product_price)) - Number(!Number(b.product_price)) ||
        Number(a.product_price) - Number(b.product_price),
      price_desc: (a, b) =>
        Number(!Number(a.product_price)) - Number(!Number(b.product_price)) ||
        Number(b.product_price) - Number(a.product_price),
      name: (a, b) => a.product_name.localeCompare(b.product_name),
    }
    // ปิดท้ายด้วย product_id เสมอ — ถ้าคะแนน/ราคา/ชื่อเท่ากัน comparator จะคืน 0
    // แล้วลำดับจะขึ้นอยู่กับลำดับแถวที่ Postgres คืนมา (findMany ด้านบนไม่มี ORDER BY)
    // ซึ่งไม่คงที่ข้าม request → แบ่งหน้าแล้วสินค้าซ้ำ/หาย แบบเดียวกับ GET /api/products
    const tieBreak = (a, b) => String(a.product_id).localeCompare(String(b.product_id))
    const sortFn = sortFns[sort] || sortFns.relevance
    const sorted = results.sort((a, b) => sortFn(a, b) || tieBreak(a, b))
    const total = sorted.length
    const paginated = sorted.slice(offset, offset + limit)
    // Did-You-Mean — ค้นไม่เจอค่อยรันซ้ำด้วยโหมด prefix เอาสินค้าใกล้เคียงมาเสนอ
    // คืนเป็นอ็อบเจ็กต์รูปเดียวกับ /autocomplete (ไม่ใช่ชื่อเปล่าๆ) เพราะหน้าเว็บต้องใช้
    // slug ทำลิงก์ให้ผู้ใช้กดเข้าหน้าสินค้าได้ทันที — เห็นชื่อที่ใช่แล้วต้องพิมพ์ค้นใหม่
    // เองอีกรอบคือให้ผู้ใช้ทำงานซ้ำโดยไม่จำเป็น
    const suggestions = total === 0
      ? searchProducts(candidates, effectiveTerm, { autocomplete: true, requireAll: false, lenient: true })
        .slice(0, 5).map(({ item }) => ({
          product_id: item.itm_code,
          product_name: item.itm_desc,
          slug: item.slug ?? null,
        }))
      : []

    res.json({
      products: paginated,
      total,
      page,
      total_pages: Math.max(1, Math.ceil(total / limit)),
      suggestions,
      // คำที่ระบบใช้ค้นจริงเมื่อกู้แป้นพิมพ์ให้ (null = ค้นด้วยคำที่ผู้ใช้พิมพ์ตรงๆ)
      // ฝั่งหน้าเว็บเอาไปขึ้นข้อความบอกผู้ใช้ว่าแสดงผลของคำไหนอยู่
      searched_as,
    })
  } catch (err) {
    console.error('Search error:', err)
    res.status(500).json({ message: 'Search failed' })
  }
})
// Autocomplete — เรียก searchProducts() ด้วยโหมด prefix แล้วตัดเหลือ 4 รายการ
router.get('/autocomplete', async (req, res) => {
  try {
    const keyword = String(req.query.searchword ?? '').trim()
    if (keyword.length < 2) return res.json({ suggestions: [] })
    const candidates = await prisma.tbl_item.findMany({
      where: { itm_flag: '1' },
      include: { item_type: true, attribute_values: { include: { attribute: true } } },
    })
    const results = searchProducts(candidates, keyword, { autocomplete: true, prefixMin: 2 })
      .slice(0, 5).map(({ item }) => item)

    res.json({
      suggestions: results.map((r) => ({
        product_id: r.itm_code,
        product_name: r.itm_desc,
        slug: r.slug ?? null,
      })),
    })
  } catch (err) {
    res.status(500).json({ message: 'Autocomplete failed' })
  }
})

module.exports = router
module.exports.searchProducts = searchProducts
module.exports.queryWords = queryWords
module.exports.swapKeyboardLayout = swapKeyboardLayout
module.exports.toggleThaiShift = toggleThaiShift