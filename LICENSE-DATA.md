# Data attribution and terms

The MIT license applies to AKsf code. It does not replace source-data terms.

- **ADF&G:** Alaska Department of Fish and Game, Division of Commercial Fisheries.
  Credit ADF&G on any map or analysis using its data. The agency provides data
  without express or implied warranty and recommends reading associated metadata.
  Preserve attribution when redistributing derivatives. The source service metadata
  is recorded by the rebuild script; source URLs are in the bundled manifest.
- **NOAA Fisheries:** U.S. government spatial products, provided as-is. Retain NOAA
  attribution and source-vintage information. ATB is a broad-scale managed-area
  inventory, not a certification of current fishing regulations.
- **Natural Earth:** public-domain cartographic data. Credit Natural Earth to help
  distinguish its generalized land from authoritative fisheries boundaries.
- **NPFMC:** plan documents are cited as the source of management definitions.
  AKsf does not redistribute Council PDFs or claim ownership of them.

Suggested map attribution: “AKsf reference geometry; NOAA Fisheries and Alaska
Department of Fish and Game spatial data; Natural Earth land. See AKsf source
manifest for retrieval dates and derivation methods.”

No agency endorsement is implied.


## NOAA closure vignette example

`inst/extdata/closure-example` contains two records from NOAA AKRO's
[Habitat_Restrictions layer](https://alaskafisheries.noaa.gov/arcgis/rest/services/Base_Map/MapServer/5):
`GOA_Slope_HCA.htm` and `GOA_Coral_HPA.htm`. Retrieved 2026-09-21; both retain
the source annotation `steve.lewis, akro, 01/19/15`. This is a historical
teaching snapshot, not a current closure inventory. Original attributes and
service geometry requested in WGS84 are preserved. The adjacent manifest
records IDs, query URL, retrieval time, and SHA-256; layer metadata is included.
NOAA/AKRO is the source; this U.S. federal government data is not relicensed
as AKsf code. Retain attribution and consult NOAA regulations and notices for
current restrictions. Regenerate with `data-raw/download-closure-example.py`.
