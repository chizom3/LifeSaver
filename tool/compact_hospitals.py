"""Convert assets/data/hospitals.json (record-per-object) to a compact
column format. Usage: compact_hospitals.py <in.json> <out.json>"""
import json, re, sys

COLUMNS = [  # (compact name, source key)
    ('id', 'data-id'), ('uniqueId', 'data-unique_id'),
    ('name', 'data-facility_name'), ('state', 'data-state'),
    ('lga', 'data-lga'), ('ward', 'data-ward'),
    ('lat', 'data-latitude'), ('lng', 'data-longitude'),
    ('phone', 'data-phone_number'), ('physicalLocation', 'data-physical_location'),
    ('alternateNumber', 'data-alternate_number'), ('facilityLevel', 'data-facility_level'),
    ('licenseStatus', 'data-license_status'), ('operationStatus', 'data-operation_status'),
    ('operationalDays', 'data-operational_days'),
    ('registrationStatus', 'data-registration_status'), ('ownership', 'data-ownership'),
]
NUMERIC = {'lat', 'lng'}

def coord(value):
    """Parse a coordinate, repairing known spreadsheet typos."""
    text = str(value or '').strip()
    text = text.lstrip(':').replace('`', '')
    text = re.split(r'\+[A-Za-z]', text)[0]  # Excel residue like '+D24900'
    try:
        return float(text) if text else 0.0
    except ValueError:
        return 0.0

def key_part(v):
    return re.sub(r'\s+', ' ', v.strip().lower())

def main(src, dst):
    records = json.load(open(src, encoding='utf-8'))
    rows = []
    for r in records:
        row = []
        for name, key in COLUMNS:
            v = r.get(key)
            row.append(coord(v) if name in NUMERIC else ('' if v is None else str(v)))
        rows.append(row)

    # Dictionary-encode repetitive columns: rows store an index instead.
    dicts = {}
    for c, (name, _) in enumerate(COLUMNS):
        if name in NUMERIC:
            continue
        values = sorted({row[c] for row in rows})
        if len(values) <= 2000:
            index = {v: i for i, v in enumerate(values)}
            for row in rows:
                row[c] = index[row[c]]
            dicts[name] = values

    # The app derives each hospital's key; prove the stored keys still match.
    names = [n for n, _ in COLUMNS]
    def val(row, n):
        c = names.index(n)
        return dicts[n][row[c]] if n in dicts else row[c]
    for r, row in zip(records, rows):
        name = val(row, 'name')
        key = '|'.join([key_part(val(row, 'uniqueId')), key_part(name),
                        key_part(val(row, 'state')), key_part(val(row, 'lga')),
                        f"{val(row, 'lat'):.5f}", f"{val(row, 'lng'):.5f}"])
        assert key == r['hospital_key'], (key, r['hospital_key'])

    out = {'version': 2, 'columns': names, 'dictionaries': dicts, 'rows': rows}
    with open(dst, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    print('records', len(rows), 'dictionary columns', sorted(dicts))

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
