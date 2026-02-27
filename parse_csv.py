import csv
import json

def parse_csv():
    # Attempt to read the CSV file
    try:
        with open('mappings.csv', 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            data = list(reader)
            
            # Find the header row, it probably contains "KSeF", "SmartKSeF", "Invoicing system"
            start_row = -1
            for i, row in enumerate(data):
                if any('Invoicing system' in str(cell) for cell in row):
                    start_row = i
                    break
            
            if start_row == -1:
                print("Could not find start of mapping data.")
                for i in range(50):
                   print(data[i])
                return
            
            headers = data[start_row]
            print(f"Found headers: {headers}")
            
            mappings = []
            for row in data[start_row+1:]:
                if not row or all(not cell.strip() for cell in row):
                    continue
                # Assuming KSeF is one column and Invoicing System is another
                # We need to find the column indices
                ksef_idx = -1
                inv_idx = -1
                for j, h in enumerate(headers):
                    if 'KSeF' in str(h) and 'Smart' not in str(h):
                        ksef_idx = j
                    elif 'Invoicing system' in str(h):
                        inv_idx = j
                
                if ksef_idx != -1 and inv_idx != -1 and len(row) > max(ksef_idx, inv_idx):
                    ksef_field = row[ksef_idx].strip()
                    inv_field = row[inv_idx].strip()
                    if ksef_field and inv_field:
                        mappings.append({
                            "KSeF": ksef_field,
                            "Invoicing System": inv_field
                        })
            
            print(json.dumps(mappings[:20], indent=2))
            
    except Exception as e:
        print(f"Error reading CSV: {e}")

parse_csv()
