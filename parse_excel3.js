const XLSX = require('xlsx');

const workbook = XLSX.readFile('1.xlsx');
['MAP_Header', 'MAP_Entities', 'MAP_FA'].forEach(sheetName => {
    if (workbook.SheetNames.includes(sheetName)) {
        console.log(`\n--- Sheet: ${sheetName} ---`);
        const sheet = workbook.Sheets[sheetName];
        const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
        
        // Find header row bounds
        let headerColIdx = -1;
        let invSysColIdx = -1;

        // Based on Row 1: [null,"Field name Translation",null,"Field name FA(2)",null,"Type of field","Limit of characters","Description","Field name","Type of field"]
        // Wait, Row 1 has "Field name FA(2)" at index 3, and "Field name" (SmartKSeF/Invoicing) at index 8 and 10?
        // Let's just print column 3 (KSeF Field) and column 9 or 10 (Invoicing System Field)
        
        let targetCol = 9; // Let's guess 9 or 10
        if (sheetName === 'MAP_Header') targetCol = 9;
        
        // Start scanning after row 2
        for(let i=2; i<data.length; i++) {
            const row = data[i];
            if (!row) continue;
            
            const ksefField = row[3]; // "Field name FA(2)"
            let invField = row[9];   // "Invoicing system"
            if (!invField && row.length > 10) invField = row[10];
            
            if (ksefField && typeof ksefField === 'string' && ksefField.trim() !== '') {
                if (invField && typeof invField === 'string' && invField.trim() !== '' && !invField.includes('Optional') && !invField.includes('Obligatory')) {
                   console.log(`${ksefField.trim()} -> ${invField.trim()}`);
                }
            }
        }
    }
});
