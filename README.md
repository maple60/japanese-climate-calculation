# japanese-climate-calculation

[日本語版のREADMEはこちら (Japanese version)](README_ja.md)

[Full documentation](https://maple60.github.io/japanese-climate-calculation/)

<p align="center">
  <img src="output/japan_climate_map_PET_year.png" width="48%" />
  <img src="output/japan_climate_map_aridity_index.png" width="48%" />
  <br />
  <sub>
    Data source:
    <a href="https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-G02-v3_0.html">
      National Land Numerical Information Download Site, Ministry of Land, Infrastructure, Transport and Tourism, Japan.
    </a>
  </sub>
</p>

A reproducible R + [Quarto](https://quarto.org/) project for processing climate mesh data in Japan and deriving additional climate indicators such as Potential Evapotranspiration (PET) and Aridity Index.

## Overview

This repository documents a workflow based on:

- Japan Meteorological Agency: [Mesh Climatology 2020](https://www.data.jma.go.jp/stats/etrn/view/atlas.html)
- MLIT National Land Numerical Information: [Average Value Mesh Data](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-G02-v3_0.html)

Main outputs include:

- Cleaned climate mesh dataset
- PET (Thornthwaite method)
- Reference ET0 (daily FAO-56 Penman–Monteith, NARO 2008–2018), documented in
  [the English notebook](notebooks/calculate_ET0.qmd) with synthetic examples
- Aridity Index (`Precipitation / PET`)
- Utility function to retrieve nearest climate values from arbitrary coordinates
- Example map visualizations for Japan

## Documentation (GitHub Pages)

The full documentation is available at:

- [https://maple60.github.io/japanese-climate-calculation/](https://maple60.github.io/japanese-climate-calculation/)

- English-first documentation is published from `docs/`.
- The JMA/MLIT chapters link to Japanese companion pages; the NARO ET0 chapter
  is currently available in English.

The site is served from `/docs` on the default branch.

## Project structure

- `index.qmd`: English landing page
- `index_ja.qmd`: Japanese landing page
- `notebooks/*.qmd`: English chapters
- `notebooks/*_ja.qmd`: Japanese chapters
- `R/get_nearest_climate_value.R`: nearest-neighbor utility function
- `R/pipeline_p0_et0.R`, `R/et0_support.R`: base R daily ET0 and period summaries
- `data/examples/et0_*_synthetic.csv`: invented inputs, safe to render
- `tests/test_et0.R`: base R checks; `tests/verify_et0_local.R`: optional local-table checks
- `_quarto.yml`: book/site configuration

## Setup

### 1. Clone repository

```bash
git clone <your-repo-url>
cd japanese-climate-calculation
```

### 2. Restore R environment

```r
renv::restore()
```

### 3. Set data directory

Set `PROJECT_DATA_DIR` in `.Renviron` (example):

```bash
PROJECT_DATA_DIR=/path/to/your/data/root
```

## Build documentation

Render the Quarto book:

```bash
quarto render
```

Generated files are written to `docs/`.

For the ET0 chapter alone, execute and render with:

```bash
Rscript --vanilla tests/test_et0.R
quarto render notebooks/calculate_ET0.qmd --to html
```

The ET0 examples execute without NARO data. Authorized local tables are read
from `PROJECT_DATA_DIR/naro-et0/2008-2018/` via `.Renviron`; run
`Rscript tests/verify_et0_local.R` to verify all yearly blocks against the
11-year means without writing data or embedding values in the site.
FAO-56 ET0 describes a grass reference surface. It differs from the existing
Thornthwaite PET in quantity, inputs and period (JMA/MLIT 1991–2020 normals).
AI uses the chosen method's denominator; seasonal ET0-based AI is
`sum(P)/sum(ET0)`. See the chapter for gaps, assumptions and cross-year winters.

## Data and license notes

This repository does **not** redistribute source datasets.
Please download required files from official sources and follow their terms of use.

Permission to externally share NARO-derived ET0 and precipitation tables is
unconfirmed. Do not publish those tables, their maps, or external share links.
The code and documentation licenses do not grant rights to the weather data.

- MLIT NLNI terms of use: https://nlftp.mlit.go.jp/ksj/other/agreement.html

## Citation and attribution

When using derivatives from NLNI datasets, include required attribution per provider terms.

## Language policy

- Source comments and core documentation are maintained in English.
- Japanese companion pages are available for accessibility and continuity.

## Contributing

Issues and pull requests are welcome.
Please keep code comments and error messages in English.

## License

Code in this repository is licensed under the [MIT License](LICENSE).

Documentation, text, and original figures are licensed under the [Creative Commons Attribution 4.0 International License (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/deed.en), unless otherwise noted.

Source climate and geospatial datasets are not redistributed in this repository and are not covered by these licenses. 
Please obtain the original datasets from the official providers and follow their terms of use.
