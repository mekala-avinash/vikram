const XLSX = require('xlsx');

const workbook = XLSX.readFile('1.xlsx');
['MAP_Header', 'MAP_Entities', 'MAP_FA'].forEach(sheetName => {
    if (workbook.SheetNames.includes(sheetName)) {
        console.log(`\n--- Sheet: ${sheetName} ---`);
        const sheet = workbook.Sheets[sheetName];
        // Read sheet as an array of arrays so we can reference by column index reliably
        const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
        
        // Find column indices by searching the first few rows
        let ksefIdx = -1;
        let invSysIdx = -1;
        
        for (let i = 0; i < 5; i++) {
            const row = data[i];
            if (!row) continue;
            for (let j = 0; j < row.length; j++) {
                const cell = String(row[j] || '').trim();
                // We want the actual field names
                if (cell === 'Field name FA(2)' || cell === 'Field name FA(3)' || cell.includes('Field name')) {
                    if (ksefIdx === -1) ksefIdx = j; // Typically KSeF is left-most
                }
                if (cell === 'Invoicing system' || cell.includes('Invoicing system') || cell === 'Field name' && j > ksefIdx) {
                     // In the smart KSeF mapping, "Field name" under "Invoicing system" refers to the source field
                     invSysIdx = j;
                }
            }
        }
        
        // Hardcode fallback based on manual inspection of first rows if auto-detect fails
        if (ksefIdx === -1) ksefIdx = 3; 
        if (invSysIdx === -1) invSysIdx = 8; // Column I is index 8 (SmartKSeF/Invoicing field name)

        for(let i=2; i<data.length; i++) {
            const row = data[i];
            if (!row) continue;
            
            const ksefField = String(row[ksefIdx] || '').trim();
            const invField = String(row[invSysIdx] || '').trim();
            
            if (ksefField && ksefField !== 'Field name FA(2)' && ksefField !== 'Field name FA(3)') {
                if (invField && invField !== 'Field name' && invField !== 'Type of field') {
                   console.log(`${ksefField} -> ${invField}`);
                }
            }
        }
    }
});
