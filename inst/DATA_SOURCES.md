# Sources, conventions, and derivation

## Source snapshots

`inst/extdata/source-manifest.json` records exact service URLs, selection queries,
retrieval timestamps, raw-response SHA-256 checksums, and source feature counts.
The raw responses are cached locally by `data-raw/download.py`; they are not
committed. The release’s compressed R datasets are committed and work offline.

| Layer | Publisher and entry point | Treatment |
|---|---|---|
| NMFS reporting areas | [NOAA AKRO Base_Map, layer 0](https://alaskafisheries.noaa.gov/arcgis/rest/services/Base_Map/MapServer/0) | All source features retained, including both parts of code 523. Code 550 is retained in data but excluded by the default getter. |
| Groundfish statistical areas | [ADF&G Groundfish_Statistical_Areas_2001, layer 0](https://services.arcgis.com/VdkVOAHovLuozJG4/arcgis/rest/services/Groundfish_Statistical_Areas_2001/FeatureServer/0) | Full native attributes, with a six-character code added. Published series: 2001-present. |
| Groundfish registration areas | [ADF&G Commercial Fisheries Groundfish Registration Areas, layer 0](https://services.arcgis.com/VdkVOAHovLuozJG4/arcgis/rest/services/Commercial_Fisheries_Groundfish_Registration_Areas/FeatureServer/0) | All eight areas, including source dates and agency codes. |
| Arctic and salmon West | [NOAA Management Areas ATB, layer 126](https://services2.arcgis.com/C8EMgrsFcRFL6LrL/arcgis/rest/services/NMFS_Management_Areas_ATB/FeatureServer/126) | Selected by agency and site name, not unstable object IDs. Last-edited source fields in the inspected snapshot are April 2023. |
| Alaska land | [Natural Earth 1:10m states/provinces](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-1-states-provinces/) | Alaska land polygon selected; no attempt to infer regulatory baselines. |

Agency entry points:
[NOAA Alaska boundaries](https://www.fisheries.noaa.gov/alaska/sustainable-fisheries/alaska-fisheries-figures-maps-boundaries-regulatory-areas-and-zones)
and [ADF&G commercial GIS](https://www.adfg.alaska.gov/index.cfm?adfg=maps.commercial_fishing_gis).

The ATB inventory provides broad-scale managed areas. Its predecessor is described
in [NOAA InPort 66840](https://www.fisheries.noaa.gov/inport/item/66840); that record’s
older `NMFS_Management_Areas` endpoint required a token when inspected. AKsf uses
the accessible, separately named ATB service above and records that actual URL.
An InPort metadata-modification date does not update the polygon vintage.

## What “following agency conventions” means

- Reporting, registration, and statistical units remain distinct.
- NMFS reporting codes remain three-character strings. ADF&G statistical codes
  are six-character strings in `area_code`; original numeric `STAT_AREA` remains.
- ADF&G’s native registration, district, subdistrict, section, sector, fishery,
  federal-reporting, IFQ, waters, and FMP fields remain available. These are agency
  assignments, not crosswalks inferred from spatial overlap.
- `WATERS_CODE` values FED, STATE, and INTL are respected. ADF&G groundfish data
  are not applied to all salmon or shellfish reporting contexts.
- ADF&G geometry dates remain in the original Unix-millisecond representation.
  The snapshot is not a complete historical archive. No “as of” option is offered.
- Source metadata may refer to NAD83 boundary definitions while the delivered
  service advertises WGS84. Imports request EPSG:4326 explicitly. AKsf then
  transforms with PROJ; it does not relabel coordinates as another datum.
- EPSG:3338 is the package’s metre-based Alaska Albers default. Projection reduces
  dateline plotting problems; it does not remove datum or source-resolution limits.

## FMP reference geometries

The [NPFMC library](https://www.npfmc.org/library/fmps-feps/) identifies six FMPs.
AKsf represents all six, with eight features because salmon has three areas.
These are broad cartographic coverage polygons, not species-stock areas, EFH,
seasonal closures, permitted fishing grounds, or independently certified legal
boundaries. Cross-fishery overlap is expected.

1. **BSAI and GOA groundfish:** dissolve only ADF&G statistical polygons whose
   `WATERS_CODE` is FED, grouped by `FMP_AREA_CODE`, then intersect with
   NOAA reporting polygons for the matching BS/AI or GOA region to trim statistical
   cells at the smooth offshore boundary. Do not dissolve the entire NOAA
   reporting layer: that would incorporate some state waters and international 550.
   [BSAI FMP overview](https://www.npfmc.org/fisheries-issues/fisheries/bsai-groundfish-fisheries/);
   [GOA FMP overview](https://www.npfmc.org/fisheries-issues/fisheries/goa-groundfish-fisheries/).
2. **BSAI crab:** the [Crab FMP](https://files.npfmc.org/fmp/Crab/CrabFMP.pdf),
   section 3.1.2 and Figure 3-1, extends south of the Aleutians eastward to Scotch
   Cap Light, **164°44′36″ W**. Combine BSAI federal coverage with the part of GOA
   federal coverage west of that meridian. Reusing only the BSAI groundfish
   polygon would miss the southern waters between 170° W and Scotch Cap.
3. **Scallop:** combine federal BSAI and GOA coverage, consistent with the
   geographic description in section 4.1 of the
   [Scallop FMP](https://www.npfmc.org/wp-content/uploads/ScallopFMP.pdf).
   Arctic waters are not added. This does not map the state’s scallop registration
   units or fishable scallop beds.
4. **Arctic:** republish the NOAA ATB Arctic Closure polygon as reference coverage.
   The [NPFMC Arctic page](https://www.npfmc.org/fisheries-issues/fisheries/fishing-in-the-arctic/)
   describes the area. The Arctic plan is not a substitute for salmon or halibut
   management; salmon coverage can overlap it.
5. **Salmon:** use section 2.2 and Figures 1–2 of the
   [October 2024 Salmon FMP](https://files.npfmc.org/fmp/Salmon/SalmonFMP.pdf).
   East is federal GOA coverage east of Cape Suckling (**143°53.6′ W**).
   Cook Inlet is federal ADF&G groundfish registration H coverage north of
   **59°46.15′ N**, selecting the connected polygon containing an interior Cook
   Inlet point (152.4° W, 60° N). Registration H also includes waters outside Cook
   Inlet, so its other components are not included. West is the NOAA ATB
   “Salmon Management Area West” geometry, with Cook Inlet explicitly removed.
   The ATB source predates Amendment 16 and inherits its existing Prince William
   Sound and Alaska Peninsula exclusions. AKsf does not infer present fishing
   permissions from that inventory or claim those exclusions have been independently
   recertified. Source-vintage and shoreline differences can cause small slivers
   between NOAA and ADF&G products.

The NOAA ATB West inventory is retained as a traceable source rather than
redrawing its complex coastal exclusions from a small-scale figure. Users needing
boundary-sensitive salmon allocations should replace it with an agency-validated
current product. All FMP features carry `boundary_status =
"cartographic_reference_not_regulatory"` and a `geometry_basis` field.

## Spatial processing and precision

`data-raw/build-data.R` is the complete derivation. Agency responses are requested
as WGS84 GeoJSON without server-side simplification. Features are transformed to
EPSG:3338, repaired with GEOS `st_make_valid()`, and returned to EPSG:4326 for the
bundled source layers. Native attributes remain; geometry repair may split invalid
components. FMP operations and area calculations occur in EPSG:3338. Meridians and
parallels used for clipping are densified at no more than 0.01° intervals before
projection. These masks only clip agency water polygons; they never replace the
EEZ/coast with rectangles. No arbitrary coastline buffer defines state waters.

Source `Shape_*` attributes are untouched metadata and may use source CRS units.
Use `sf::st_area()` on transformed geometry for new measurements; FMP `area_km2`
is computed in Alaska Albers. The build records geometry checks and R/library
versions in `inst/extdata`. SHA-256 hashes cover the raw assembled GeoJSON bytes,
not the transformed `.rda` bytes. Rebuilding against a changed live service is an
intentional data update, not guaranteed reproduction of an earlier release.

## Known gaps

This release includes no bathymetry, high-resolution NOAA shoreline, IPHC polygons,
crab stock boundaries, species-specific closure calendar, or statewide salmon
statistical-area compilation. Registration and statistical snapshots are the
published groundfish series. FMP derivations have not been certified by the
agencies. Validation tests establish code behavior, topology, and selected spatial
relationships; they cannot prove legal equivalence to every FMP amendment.


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
