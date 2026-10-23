// Verify the generated static site without adding a browser/test dependency.
// node tests/check_bilingual.cjs [output-directory]
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const root = path.resolve(process.argv[2] || "docs");
const pages = ["index.html", ...[
  "prepare_climate_data", "calculate_PET", "calculate_aridity_index",
  "calculate_ET0", "get_nearest_climate_value", "plot_japan_climate_map",
  "bilingual_quarto",
].map(name => `notebooks/${name}.html`)];
let references = 0;
for (const language of ["en", "ja"]) {
  for (const page of pages) {
    const relative = (language === "ja" ? "ja/" : "") + page;
    const file = path.join(root, relative);
    const html = fs.readFileSync(file, "utf8");
    assert.match(html, new RegExp(`<html[^>]*\\blang="${language}"`), relative);
    const switchTag = [...html.matchAll(/<a\b[^>]*>/g)]
      .map(match => match[0]).find(tag => /\bid="language-switch"/.test(tag));
    assert(switchTag, `${relative}: missing page language switch`);
    const href = switchTag.match(/\bhref="([^"]+)"/)[1];
    const other = path.resolve(path.dirname(file), href);
    const expected = path.join(root, (language === "en" ? "ja/" : "") + page);
    assert.equal(other, expected, `${relative}: switch must keep the same page`);
    assert.match(html, /querySelector\("#language-switch"\)/, relative);
    for (const match of html.matchAll(/(?:href|src)="([^"#]+)"/g)) {
      let target = match[1].replaceAll("&amp;", "&");
      if (/^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(target)) continue;
      target = target.split(/[?#]/)[0];
      if (!target) continue;
      const destination = path.resolve(path.dirname(file), decodeURIComponent(target));
      assert(fs.existsSync(destination), `${relative}: missing ${target}`);
      references++;
    }
    if (page === "notebooks/bilingual_quarto.html") {
      assert.match(html, new RegExp(`<img[^>]+src="[^"]*bilingual-quarto-${language}[.]svg"`),
        `${relative}: guide must include its language-specific diagram`);
      assert.equal([...html.matchAll(/<h3\b/g)].length, 7,
        `${relative}: guide must include all seven steps`);
    }
    if (page === "notebooks/calculate_ET0.html") {
      assert.match(html, /3\.879455/, "FAO example must execute");
      assert.match(html, /<math\b/, "ET0 equations must use native MathML");
      assert.doesNotMatch(html, /C:[/\\]Users|cell-output-error/);
      if (language === "ja") {
        assert.match(html, /日別計算式と仮定/);
        assert.doesNotMatch(html, /<h2[^>]*>Scope and relation to PET/);
        assert.match(html, /NAROの元データが表す高度は未確認/);
      } else {
        assert.match(html, /Scope and relation to PET/);
        assert.doesNotMatch(html, /<h2[^>]*>日別計算式と仮定/);
      }
    }
  }
}
const legacyPages = pages.filter(page => !/calculate_ET0|bilingual_quarto/.test(page));
for (const page of legacyPages) {
  const legacy = page.replace(/\.html$/, "_ja.html");
  const html = fs.readFileSync(path.join(root, legacy), "utf8");
  assert.doesNotMatch(html, /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/,
    `${legacy}: redirect must not contain encoding damage`);
  const target = html.match(/rel="canonical" href="([^"]+)"/)[1];
  assert.equal(path.resolve(path.dirname(path.join(root, legacy)), target),
    path.join(root, "ja", page), legacy);
}
assert(!fs.existsSync(path.join(root, "naro-et0")), "Real NARO bundle must stay outside the site");
assert(!fs.existsSync(path.join(root, "data/naro-et0")), "Real NARO bundle must stay outside the site");
console.log(`${pages.length * 2} language pages, ${legacyPages.length} legacy redirects and ${references} local references passed.`);
