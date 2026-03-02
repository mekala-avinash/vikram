const fs = require('fs');
const { execSync } = require('child_process');

const xml = `
<CanonicalInvoice>
	<Header>
		<InvoiceNumber>INV-Test-000052-26</InvoiceNumber>
		<IssueDate>2026-02-19</IssueDate>
		<DueDate>2026-04-30</DueDate>
		<Currency>EUR</Currency>
	</Header>
	<Parties>
		<Seller>
			<Name>Eurofins Biolab Srl</Name>
			<TaxId>GST001234</TaxId>
			<Address>
				<Street>Via Bruno Buozzi,2 I-20090  Vimodrone (MI) ITALY </Street>
				<City />
				<PostalCode />
				<Country> IT</Country>
			</Address>
		</Seller>
		<Buyer>
			<Name>eLIMS-BPT Test Account</Name>
			<TaxId>99-9999999</TaxId>
			<Address>
				<Street>B4 Maruthi, Sapphire</Street>
				<City />
				<PostalCode>17605</PostalCode>
				<Country>US</Country>
			</Address>
		</Buyer>
	</Parties>
	<Lines>
		<LineItem Number="1">
			<Product>
				<Name>Batch# ZN25AA1133 Project Uat for Water -- Sample# ZN25AA1133-1 test r10.2.0; Original Received Date 19-Nov-2025 -- QC811 - TEST 11</Name>
				<SKU>TST-ZD-0000259916</SKU>
			</Product>
			<Quantity Unit="szt">1</Quantity>
			<UnitPrice>140.00</UnitPrice>
			<NetAmount>140.00</NetAmount>
			<Tax>
				<Rate>0</Rate>
				<Amount>0.00</Amount>
			</Tax>
			<GrossAmount>0.00</GrossAmount>
		</LineItem>
		<LineItem Number="2">
			<Product>
				<Name>Batch# ZN25AA1133 Project Uat for Water -- GP03S - GC Setup EP Comp of FA for GP03Q (for UAT Only)</Name>
				<SKU>BCG-JE4Q-25-323-0051</SKU>
			</Product>
			<Quantity Unit="szt">1</Quantity>
			<UnitPrice>646.00</UnitPrice>
			<NetAmount>646.00</NetAmount>
			<Tax>
				<Rate>0</Rate>
				<Amount>0.00</Amount>
			</Tax>
			<GrossAmount>0.00</GrossAmount>
		</LineItem>
	</Lines>
	<Summary>
		<TotalNetAmount>786.00</TotalNetAmount>
		<TotalTaxAmount>0.00</TotalTaxAmount>
		<TotalGrossAmount>0.00</TotalGrossAmount>
	</Summary>
</CanonicalInvoice>
`;
fs.writeFileSync('test_input.xml', xml);
console.log(execSync('xsltproc logic-app/maps/KsefFa3.xslt test_input.xml').toString());
