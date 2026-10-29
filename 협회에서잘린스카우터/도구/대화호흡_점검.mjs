import fs from 'node:fs';
import path from 'node:path';

// 후보를 찾는 도구다. 점수만으로 원고를 수정하거나 합격 처리하지 않는다.
const root = path.resolve(import.meta.dirname, '..', '원고');
const start = Number(process.argv[2] ?? 1);
const end = Number(process.argv[3] ?? 65);
const show = Number(process.argv[4] ?? 2);

function isDialogue(line) {
  return /^\s*["“]/u.test(line);
}
function content(line) {
  return line.trim().replace(/^["“]|["”]$/gu, '').trim();
}
function isBrief(line) {
  return content(line).length <= 17;
}

for (let n = start; n <= end; n++) {
  const name = String(n).padStart(3, '0');
  const lines = fs.readFileSync(path.join(root, `${name}.md`), 'utf8').split(/\r?\n/u);
  const spans = [];
  let current = [];
  const flush = () => {
    if (current.filter(x => x.dialogue).length >= 3) spans.push(current);
    current = [];
  };
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line || line === '*') {
      if (line === '*') flush();
      continue;
    }
    if (isDialogue(line)) {
      current.push({ number: i + 1, text: line, dialogue: true });
      continue;
    }
    if (current.length && line.length <= 75 && !line.startsWith('#') && !line.startsWith('```')) {
      current.push({ number: i + 1, text: line, dialogue: false });
      continue;
    }
    flush();
  }
  flush();
  const ranked = spans.map(items => {
    const quotes = items.filter(x => x.dialogue);
    const brief = quotes.filter(x => isBrief(x.text)).length;
    const generic = quotes.filter(x => /^(네\??|예\??|아니요\.?|그래요\.?|그렇죠\.?|알겠습니다\.?|\.\.\.|…|어\.?|왜요\??)$/u.test(content(x.text))).length;
    const score = brief * 2 + generic * 3 + quotes.length * 0.5;
    return { items, quotes: quotes.length, brief, generic, score };
  }).sort((a, b) => b.score - a.score);
  const total = lines.filter(isDialogue).length;
  console.log(`${name}  대사 ${total}줄  후보 ${ranked.length}구간  최고점 ${ranked[0]?.score ?? 0}`);
  for (const span of ranked.slice(0, show)) {
    console.log(`  ${span.items[0].number}-${span.items.at(-1).number}  대사 ${span.quotes} / 단답 ${span.brief} / 단독응답 ${span.generic}`);
    for (const item of span.items.slice(0, 18)) {
      console.log(`    ${item.number}: ${item.text.slice(0, 95)}`);
    }
    if (span.items.length > 18) console.log('    …');
  }
}
