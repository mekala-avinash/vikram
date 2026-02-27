const XLSX = require('xlsx');

const workbook = XLSX.readFile('1.xlsx');
['MAP_Header', 'MAP_Entities', 'MAP_FA'].forEach(sheetName => {
    if (workbook.SheetNames.includes(sheetName)) {
        console.log(`\n--- Sheet: ${sheetName} ---`);
        const sheet = workbook.Sheets[sheetName];
        const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
        
        let path = [];
        for(let i=2; i<data.length; i++) {
            const row = data[i];
            if (!row) continue;
            
            // Check the indentation column (index 1 is usually "‡" or similar if nested)
            // But let's just use the direct KSeF field and SmartKSeF field
            const ksefField = String(row[3] || '').trim();
            const smartField = String(row[8] || '').trim();
            const desc = String(row[9] || '').trim();
            const type = String(row[5] || '').trim();
            
            if (ksefField && !['Field name FA(2)', 'Node'].includes(ksefField)) {
                if (smartField && !['Node'].includes(desc) && smartField !== "Field replenished automatically by the SmartKSeF system") {
                   console.log(`${ksefField} [${type}] -> ${smartField}`);
                }
            }
        }
    }
});
