# Contributing

Keep changes to area geometry separate from interface changes. For a data update:

1. Confirm the authoritative agency source, its effective period, datum, field
   definitions, and redistribution terms. Do not substitute EFH or a reporting
   grid for an FMP boundary.
2. Refresh downloads and inspect service metadata; review changes in counts,
   SHA-256 hashes, native identifiers, and dates. Retrieval dates are not vintages.
3. Rebuild with `data-raw/build-data.R`. Compare coverage and inspect maps,
   especially the Aleutian dateline, Donut Hole, state-water exclusions, Scotch
   Cap, Cape Suckling, and the three salmon management areas.
4. Update the plan catalog, methods, limitations, tests, and NEWS. Record any
   source change that makes a boundary incomparable to an earlier release.
5. Generate documentation, run `R CMD build` and `R CMD check`, and review the
   resulting diff. Never commit raw caches, tokens, or local check directories.

Useful next datasets include NOAA bathymetry, IPHC areas, ADF&G salmon district
layers, and species-specific crab management units. Add each as its own documented
layer with its own identifiers rather than forcing it into a groundfish grid.
