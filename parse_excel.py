import pandas as pd

xls = pd.ExcelFile('1.xlsx')

for sheet in ['MAP_Header', 'MAP_Entities', 'MAP_FA']:
    if sheet in xls.sheet_names:
        df = pd.read_excel(xls, sheet_name=sheet, header=None)
        
        # Search for row containing 'Field name FA(2)' or similar
        header_row = -1
        ksef_col = -1
        inv_col = -1
        
        for idx, row in df.iterrows():
            row_vals = [str(x).strip() for x in row.values]
            if 'Field name FA(2)' in row_vals or 'Field name FA(3)' in row_vals or 'KSeF' in row_vals:
                header_row = idx
                for c_idx, val in enumerate(row_vals):
                    if 'FA(2)' in val or 'FA(3)' in val or val == 'KSeF':
                        ksef_col = c_idx
                    if 'Invoicing system' in val or val == 'SmartKSeF':
                        # Try to find the actual field name column under "Invoicing system"
                        # Usually it's the next column or the one after
                        pass
                break
                
        # Let's just print the raw data for columns C/D (KSeF) and I/J (Invoicing)
        print(f"\n--- {sheet} ---")
        for idx, row in df.iterrows():
            if idx > header_row and header_row != -1:
                ksef = str(row.values[3]).strip() if len(row.values) > 3 else ''
                inv = str(row.values[8]).strip() if len(row.values) > 8 else ''
                inv2 = str(row.values[9]).strip() if len(row.values) > 9 else ''
                
                if ksef and ksef != 'nan' and ksef != 'Field name FA(2)':
                    print(f"{ksef} -> {inv} | {inv2}")
