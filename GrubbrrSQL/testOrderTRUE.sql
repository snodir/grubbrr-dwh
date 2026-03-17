select *
from fact.transactionheader
where orderid in (
'ord-AAACEMQH9QAG',
'ord-AAACEMQH9QAF',
'ord-d31612a67d8040bdb534d23ddc17c13600018321',
'ord-c9f565c94966407badd561f10787a1f500018321',
'ord-1538cd82267745b5b16aefc5cfa6797500018321',
'ord-78644',
'ord-78643',
'ord-78642',
'ord-ea7ab60462a44c77849f186d7978b9ac00018321',
'ord-8de72d197870465c8cc765c19d36359a00018321',
'ord-12447',
'ord-12446',
'ord-12445',
'ord-12444',
'ord-12443',
'ord-12442',
'ord-12441',
'ord-12440',
'ord-78640',
'ord-12423',
'ord-',
'ord-12416',
'ord-64ea4538-3435-40f6-a026-6768e5313d6b')
and dateid BETWEEN 2025011600 and 2025011723;

select * 
from fact.transactionitem
where orderid in (
'ord-AAACEMQH9QAG',
'ord-AAACEMQH9QAF',
'ord-d31612a67d8040bdb534d23ddc17c13600018321',
'ord-c9f565c94966407badd561f10787a1f500018321',
'ord-1538cd82267745b5b16aefc5cfa6797500018321',
'ord-78644',
'ord-78643',
'ord-78642',
'ord-ea7ab60462a44c77849f186d7978b9ac00018321',
'ord-8de72d197870465c8cc765c19d36359a00018321',
'ord-12447',
'ord-12446',
'ord-12445',
'ord-12444',
'ord-12443',
'ord-12442',
'ord-12441',
'ord-12440',
'ord-78640',
'ord-12423',
'ord-',
'ord-12416',
'ord-64ea4538-3435-40f6-a026-6768e5313d6b')
and dateid BETWEEN 2025011600 and 2025011723
