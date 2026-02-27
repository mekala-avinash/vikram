const XLSX = require('xlsx');

const workbook = XLSX.readFile('1.xlsx');
['MAP_Header', 'MAP_Entities', 'MAP_FA'].forEach(sheetName => {
    if (workbook.SheetNames.includes(sheetName)) {
        console.log(`\n--- Sheet: ${sheetName} ---`);
        const sheet = workbook.Sheets[sheetName];
        const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
        
        // Print the first 15 rows to let me inspect the header structures directly
        for(let i=0; i<15 && i<data.length; i++) {
           console.log(`Row ${i}:`, JSON.stringify(data[i].slice(0, 10)));
        }
    }
});
