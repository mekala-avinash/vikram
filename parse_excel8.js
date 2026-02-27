const XLSX = require('xlsx');

const workbook = XLSX.readFile('1.xlsx');
['MAP_Entities'].forEach(sheetName => {
    if (workbook.SheetNames.includes(sheetName)) {
        const sheet = workbook.Sheets[sheetName];
        const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
        
        // Let's print out rows 4 through 15 completely to see the actual fields under "Seller.identity" and "Seller.address"
        for(let i=4; i<16; i++) {
             console.log(`Row ${i}:`, JSON.stringify(data[i]));
        }
    }
});
