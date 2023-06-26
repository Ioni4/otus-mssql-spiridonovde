/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "06 - Оконные функции".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters
/*
1. Сделать расчет суммы продаж нарастающим итогом по месяцам с 2015 года 
(в рамках одного месяца он будет одинаковый, нарастать будет в течение времени выборки).
Выведите: id продажи, название клиента, дату продажи, сумму продажи, сумму нарастающим итогом

Пример:
-------------+----------------------------
Дата продажи | Нарастающий итог по месяцу
-------------+----------------------------
 2015-01-29   | 4801725.31
 2015-01-30	 | 4801725.31
 2015-01-31	 | 4801725.31
 2015-02-01	 | 9626342.98
 2015-02-02	 | 9626342.98
 2015-02-03	 | 9626342.98
Продажи можно взять из таблицы Invoices.
Нарастающий итог должен быть без оконной функции.
*/

with first_query as ( 
	select 
		InvoiceID, sum(ExtendedPrice) as invsum,
		(select InvoiceDate from sales.Invoices i where i.InvoiceID=il.InvoiceID) as invdate, 
		(select CustomerID from sales.Invoices i where i.InvoiceID=il.InvoiceID) as custID 
	from sales.InvoiceLines il
	group by InvoiceID)
select 
	fq.*, 
	(select sum(invsum) from first_query where year(invdate)<=year(fq.invdate) and month(invdate)<=month(fq.invdate)) as invsumcum 
from first_query fq
order by fq.InvoiceID
--88 секунд

/*
2. Сделайте расчет суммы нарастающим итогом в предыдущем запросе с помощью оконной функции.
   Сравните производительность запросов 1 и 2 с помощью set statistics time, io on
*/

with f_q as (
	select 
		i.invoiceID, i.CustomerID, i.InvoiceDate, 
		sum(il.ExtendedPrice) as sum_inv
	from sales.Invoices i
	left join sales.InvoiceLines il on il.invoiceID=i.invoiceID
	group by i.InvoiceID, i.CustomerID, i.InvoiceDate
	)
select *,
	sum(sum_inv) over (order by datetrunc(month,invoicedate) asc) as cum_sum_inv
from f_q
order by InvoiceID

--<1 сек.

/*
3. Вывести список 2х самых популярных продуктов (по количеству проданных) 
в каждом месяце за 2016 год (по 2 самых популярных продукта в каждом месяце).
*/

with f_q as (
	select 
		il.invoiceID, il.StockItemID, quantity, 
		(select InvoiceDate from sales.Invoices i where i.InvoiceID=il.InvoiceID) as invdate 
	from sales.InvoiceLines il
),
s_q as (
	select 
		datetrunc(month,invdate) as datemonth, 
		StockItemID, 
		sum(quantity) as qant
	from f_q
	group by datetrunc(month,invdate), StockItemID
),
t_q as (
	select *,
		dense_rank() over (partition by datetrunc(month,datemonth) order by qant desc) as rank_qant
	from s_q
)
select * 
from t_q
where rank_qant <=2
order by datemonth, rank_qant

/*
4. Функции одним запросом
Посчитайте по таблице товаров (в вывод также должен попасть ид товара, название, брэнд и цена):
* пронумеруйте записи по названию товара, так чтобы при изменении буквы алфавита нумерация начиналась заново
* посчитайте общее количество товаров и выведете полем в этом же запросе
* посчитайте общее количество товаров в зависимости от первой буквы названия товара
* отобразите следующий id товара исходя из того, что порядок отображения товаров по имени 
* предыдущий ид товара с тем же порядком отображения (по имени)
* названия товара 2 строки назад, в случае если предыдущей строки нет нужно вывести "No items"
* сформируйте 30 групп товаров по полю вес товара на 1 шт

Для этой задачи НЕ нужно писать аналог без аналитических функций.
*/

With f_q as (
	select 
		si.StockItemID,StockItemName,TypicalWeightPerUnit, brand, UnitPrice, h.QuantityOnHand,
		left(trim('"' from StockItemName),1) as firstletter
	from Warehouse.StockItems si
	left join Warehouse.StockItemHoldings h on h.StockItemID=si.StockItemID
)
select *,
	ROW_NUMBER() over (partition by firstletter order by firstletter) as first_num,
	sum(quantityonhand) over () as sec_sum,
	sum(quantityonhand) over (partition by firstletter) as third_sum,
	lead(stockitemid,1) over (order by firstletter,stockitemname) as fourth_lead,
	lag(stockitemid,1) over (order by firstletter,stockitemname) as fifth_lag,
	coalesce(lag(stockitemname,2) over (order by firstletter,stockitemname),'No items') as sixth_lag2,
	dense_rank() over (order by typicalweightperunit) as seventh_group --не понял про 30 групп, их всего 23 с разным весом
from f_q
order by typicalweightperunit

/*
5. По каждому сотруднику выведите последнего клиента, которому сотрудник что-то продал.
   В результатах должны быть ид и фамилия сотрудника, ид и название клиента, дата продажи, сумму сделки.
*/

with first_query as ( 
	select 
		InvoiceID, sum(ExtendedPrice) as invsum,
		(select InvoiceDate from sales.Invoices i where i.InvoiceID=il.InvoiceID) as invdate, 
		(select CustomerID from sales.Invoices i where i.InvoiceID=il.InvoiceID) as custID, 
		(select SalespersonPersonID from sales.Invoices i where i.InvoiceID=il.InvoiceID) as saleID from sales.InvoiceLines il
	group by InvoiceID
),
s_q as(
	select *,
		ROW_NUMBER() over (partition by saleID order by invdate desc) as rank_sales
	from first_query
)
select *,
	(select FullName from Application.People p where p.PersonID=saleID) as salesname,
	(select CustomerName from sales.Customers c where c.CustomerID=custID) as customername
from s_q
where rank_sales = 1

/*
6. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/

with f_q as (
	select 
		il.invoiceID, il.StockItemID, unitprice,
		(select InvoiceDate from sales.Invoices i where i.InvoiceID=il.InvoiceID) as invdate, 
		(select CustomerID from sales.Invoices i where i.InvoiceID=il.InvoiceID) as customer
	from sales.InvoiceLines il
),
s_q as(
	select *,
		row_number() over (partition by customer order by unitprice desc) as rank_price
	from f_q
)
select *,
	(select CustomerName from sales.Customers c where c.CustomerID=customer) as customername
from s_q
where rank_price <= 2
order by customer

--если нужны 2 УНИКАЛЬНЫХ товара, которые покупатель когда-то покупал (т.к. он мог товар покупать несколько раз и не указано что дата покупки должна быть последней, то в выборке может быть несколько строк с одним и тем же товаром).

with f_q as (
	select 
		il.invoiceID, il.StockItemID, unitprice,
		(select InvoiceDate from sales.Invoices i where i.InvoiceID=il.InvoiceID) as invdate, 
		(select CustomerID from sales.Invoices i where i.InvoiceID=il.InvoiceID) as customer
	from sales.InvoiceLines il
),
s_q as(
	select *,
		row_number() over (partition by customer order by unitprice desc) as rank_price
	from f_q
),
t_q as (
	select *,
		dense_rank() over (partition by customer order by unitprice desc) as rank_uniq_price,
		(select CustomerName from sales.Customers c where c.CustomerID=customer) as customername
	from s_q
)
select * from t_q
where rank_uniq_price<=2

Опционально можете для каждого запроса без оконных функций сделать вариант запросов с оконными функциями и сравнить их производительность. 