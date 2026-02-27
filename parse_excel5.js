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
            
            // KSeF field is usually at index 3 or 4.
            const ksefField = String(row[3] || '').trim();
            
            // The mapping to the internal system is on the right. Let's dump indices 8, 9, 10
            const col8 = String(row[8] || '').trim();
            const col9 = String(row[9] || '').trim();
            const col10 = String(row[10] || '').trim();
            
            if (ksefField && ksefField.length > 0 && ksefField !== 'Field name FA(2)' && ksefField !== 'Field name FA(3)') {
                // If it's a structural node, it might not have a mapping
                if (col8 || col9 || col10) {
                    console.log(`[${ksefField}] -> [8: ${col8}] [9: ${col9}] [10: ${col10}]`);
                }
            }
        }
    }
});
