"""Download complete agency snapshots; run from the repository root.
Python standard library only. Existing cache is reused unless --refresh is set.
Object-ID batching avoids ArcGIS transfer-limit truncation.
"""
import concurrent.futures
import datetime
import hashlib
import json
from pathlib import Path
import sys
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'data-raw' / 'cache'
CACHE.mkdir(exist_ok=True)
SOURCES = {
    'nmfs_reporting_areas': ('https://alaskafisheries.noaa.gov/arcgis/rest/services/Base_Map/MapServer/0', '1=1'),
    'adfg_groundfish_statistical_areas': ('https://services.arcgis.com/VdkVOAHovLuozJG4/arcgis/rest/services/Groundfish_Statistical_Areas_2001/FeatureServer/0', '1=1'),
    'adfg_groundfish_registration_areas': ('https://services.arcgis.com/VdkVOAHovLuozJG4/arcgis/rest/services/Commercial_Fisheries_Groundfish_Registration_Areas/FeatureServer/0', '1=1'),
    'salmon_west_source': ('https://services2.arcgis.com/C8EMgrsFcRFL6LrL/arcgis/rest/services/NMFS_Management_Areas_ATB/FeatureServer/126', "SiteName = 'Salmon Management Area West' AND Action_Organization = 'NPFMC'"),
    'arctic_management_area': ('https://services2.arcgis.com/C8EMgrsFcRFL6LrL/arcgis/rest/services/NMFS_Management_Areas_ATB/FeatureServer/126', "SiteName = 'Arctic Closure' AND Action_Organization = 'NPFMC'"),
}

def request(url, params):
    url += '?' + urllib.parse.urlencode(params)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=180) as response:
                obj = json.load(response)
            if 'error' in obj:
                raise RuntimeError(obj['error'])
            return obj
        except Exception:
            if attempt == 3:
                raise
            time.sleep(2 ** attempt)

def download(item):
    name, (url, where) = item
    target = CACHE / (name + '.geojson')
    record = CACHE / (name + '.provenance.json')
    if target.exists() and record.exists() and '--refresh' not in sys.argv:
        info = json.loads(record.read_text())
        if hashlib.sha256(target.read_bytes()).hexdigest() != info['sha256']:
            raise RuntimeError('Cached snapshot checksum mismatch: ' + name)
        print('Using cache:', name, flush=True)
        return info
    meta = request(url, {'f': 'json'})
    ids = request(url + '/query', {'where': where, 'returnIdsOnly': 'true', 'f': 'json'})
    object_ids = sorted(ids['objectIds'])
    if not object_ids:
        raise RuntimeError('Empty source: ' + name)
    features = []
    for start in range(0, len(object_ids), 50):
        part = request(url + '/query', {
            'objectIds': ','.join(map(str, object_ids[start:start+50])),
            'outFields': '*', 'returnGeometry': 'true', 'outSR': 4326, 'f': 'geojson',
        })
        if part.get('exceededTransferLimit'):
            raise RuntimeError('Transfer limit reached: ' + name)
        features.extend(part['features'])
    oid = ids['objectIdFieldName']
    received = [f['properties'][oid] for f in features]
    if sorted(received) != object_ids:
        raise RuntimeError('Missing/duplicate features: ' + name)
    if any(f.get('geometry') is None for f in features):
        raise RuntimeError('Missing geometry: ' + name)
    payload = json.dumps({'type': 'FeatureCollection', 'features': features}, separators=(',', ':')).encode()
    target.write_bytes(payload)
    (CACHE / (name + '.metadata.json')).write_text(json.dumps(meta, indent=2))
    info = dict(dataset=name, source_url=url, where=where, retrieved_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                feature_count=len(features), output_crs='EPSG:4326', sha256=hashlib.sha256(payload).hexdigest(),
                source_crs=meta.get('extent', {}).get('spatialReference'), source_editing_info=meta.get('editingInfo'))
    record.write_text(json.dumps(info, indent=2))
    print(name, len(features), 'features;', len(payload), 'bytes', flush=True)
    return info

if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        records = list(pool.map(download, SOURCES.items()))
    coast_url = 'https://naturalearth.s3.amazonaws.com/10m_cultural/ne_10m_admin_1_states_provinces.zip'
    coast = CACHE / 'ne_10m_admin_1_states_provinces.zip'
    coast_record = CACHE / 'coast10.provenance.json'
    if not coast.exists() or '--refresh' in sys.argv:
        urllib.request.urlretrieve(coast_url, coast)
        coast_record.write_text(json.dumps(dict(dataset='alaska_coast', source_url=coast_url,
            retrieved_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            sha256=hashlib.sha256(coast.read_bytes()).hexdigest())))
    coast_info = json.loads(coast_record.read_text())
    if hashlib.sha256(coast.read_bytes()).hexdigest() != coast_info['sha256']:
        raise RuntimeError('Cached coastline checksum mismatch')
    records.append(coast_info)
    metadata_dir = ROOT / 'inst/extdata/metadata'
    metadata_dir.mkdir(exist_ok=True)
    for name in SOURCES:
        metadata = CACHE / (name + '.metadata.json')
        (metadata_dir / metadata.name).write_bytes(metadata.read_bytes())
    (ROOT / 'inst/extdata/source-manifest.json').write_text(json.dumps(records, indent=2) + '\n')
