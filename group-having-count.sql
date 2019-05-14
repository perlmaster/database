select ip_address_1,count(*) IP1
from ip_list
group by ip_address_1
having count(*) > 1
order by IP1;

select NSS+'.'+ProjectID as stuff,count(*) mycount
from CPA
group by NSS+'.'+ProjectID
order by mycount desc;

SELECT BankerState, BankerCity, COUNT(*) AS BillingQty,
AVG(BillingTotal) AS BillingAvg
FROM Billings JOIN Bankers
ON Billings.BankerID = Bankers.BankerID
GROUP BY BankerState, BankerCity
ORDER BY BankerState, BankerCity;

select purchase_date, item, sum(items_purchased) as "Total Items"
from Purchases
group by item, purchase_date;
