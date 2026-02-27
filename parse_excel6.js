const XLSX = require('xlsx');

const workbook = XLSX.readFile('1.xlsx');
['MAP_Header', 'MAP_Entities', 'MAP_FA'].forEach(sheetName => {
    if (workbook.SheetNames.includes(sheetName)) {
        console.log(`\n--- Sheet: ${sheetName} ---`);
        const sheet = workbook.Sheets[sheetName];
        const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
        
        for(let i=2; i<data.length; i++) {
            const row = data[i];
            if (!row) continue;
            
            // KSeF actual field names
            const ksefField = String(row[3] || '').trim();
            const smartField = String(row[8] || '').trim();
            const desc = String(row[9] || '').trim();
            
            // Filter to actual leaf-level mapping definitions
            if (ksefField && !['Field name FA(2)', 'Node'].includes(ksefField)) {
                if (smartField && !smartField.includes('Optional') && !['Node'].includes(desc)) {
                    console.log(`${ksefField} -> ${smartField}`);
                }
            }
        }
    }
});
