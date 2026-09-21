"""Refresh only the two-feature, historical NOAA vignette example."""
from pathlib import Path
from urllib.request import urlopen
from urllib.parse import urlencode
from datetime import datetime, timezone
import hashlib
import json

out = Path(__file__).resolve().parents[1] / 'inst/extdata/closure-example'
out.mkdir(parents=True, exist_ok=True)
service = 'https://alaskafisheries.noaa.gov/arcgis/rest/services/Base_Map/MapServer/5'
where = "HTM IN ('GOA_Slope_HCA.htm','GOA_Coral_HPA.htm')"

def fetch(params, query=True):
    url = service + ('/query' if query else '') + '?' + urlencode(params)
    with urlopen(url, timeout=90) as response:
        raw = response.read()
    obj = json.loads(raw)
    if 'error' in obj:
        raise RuntimeError(obj['error'])
    return url, raw, obj

_, _, ids = fetch(dict(where=where, returnIdsOnly='true', f='json'))
expected = sorted(ids['objectIds'])
assert expected, 'No matching example features'
url, raw, obj = fetch(dict(objectIds=','.join(map(str, expected)),
                           outFields='*', outSR=4326, returnGeometry='true', f='geojson'))
assert not obj.get('exceededTransferLimit', False)
assert sorted(f['properties']['OBJECTID'] for f in obj['features']) == expected
(out / 'goa-habitat.geojson').write_bytes(raw)
_, metadata, _ = fetch(dict(f='pjson'), query=False)
(out / 'layer-metadata.json').write_bytes(metadata)
manifest = dict(source_url=service, query_url=url, where=where,
                retrieved_utc=datetime.now(timezone.utc).isoformat(),
                feature_count=len(expected), object_ids=expected,
                sha256=hashlib.sha256(raw).hexdigest(),
                source_dtd=sorted({f['properties']['dtd'] for f in obj['features']}),
                status='Historical GIS teaching example, not current closure status',
                geometry='Unmodified service response, requested WGS84 EPSG:4326')
(out / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
print(json.dumps(manifest, indent=2))
