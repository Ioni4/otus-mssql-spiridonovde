/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "03 - Подзапросы, CTE, временные таблицы".
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
-- Для всех заданий, где возможно, сделайте два варианта запросов:
--  1) через вложенный запрос
--  2) через WITH (для производных таблиц)
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Выберите сотрудников (Application.People), которые являются продажниками (IsSalesPerson), 
и не сделали ни одной продажи 04 июля 2015 года. 
Вывести ИД сотрудника и его полное имя. 
Продажи смотреть в таблице Sales.Invoices.
*/

--Подзапрос
select PersonID, FullName
from 
Application.People
where IsSalesperson=1 and PersonID not in (select distinct SalespersonPersonID from sales.invoices where InvoiceDate >='20150704' and InvoiceDate<'20150705');

--CTE
WITH InvoicesCTE AS (
	select distinct SalespersonPersonID 
	from sales.invoices 
	where InvoiceDate >='20150704' and InvoiceDate<'20150705'
)
select PersonID, FullName
from Application.People p
where p.IsSalesperson=1 and p.PersonID not in (select * from InvoicesCTE);

/*
2. Выберите товары с минимальной ценой (подзапросом). Сделайте два варианта подзапроса. 
Вывести: ИД товара, наименование товара, цена.
*/
--Подзапрос
select StockItemID, StockItemName, UnitPrice from Warehouse.StockItems
where UnitPrice = (select min(unitprice) from Warehouse.StockItems);

--Подзапрос 2
select StockItemID, StockItemName, UnitPrice from Warehouse.StockItems
where UnitPrice <= all (select UnitPrice from Warehouse.StockItems);

--CTE
WITH StockCTE AS (select min(unitprice) as minprice from Warehouse.StockItems)
select StockItemID, StockItemName, UnitPrice from Warehouse.StockItems
where UnitPrice = (select * from StockCTE);

/*
3. Выберите информацию по клиентам, которые перевели компании пять максимальных платежей 
из Sales.CustomerTransactions. 
Представьте несколько способов (в том числе с CTE). 
*/

--Подзапрос (только информация о покупателях)
select customerID, customerName from sales.Customers
where customerID in (select top(5) customerID from sales.CustomerTransactions order by TransactionAmount desc);

--CTE (с информацией о кол-ве и сумме транзакций)
WITH TransCTE AS (select top(5) * from sales.CustomerTransactions order by TransactionAmount desc)
select ts.CustomerID,cs.CustomerName, count(ts.CustomerTransactionID) as transcount, sum(ts.TransactionAmount) as transamount from TransCTE ts
inner join sales.Customers cs on cs.CustomerID=ts.CustomerID
group by ts.CustomerID, cs.CustomerName;

/*
4. Выберите города (ид и название), в которые были доставлены товары, 
входящие в тройку самых дорогих товаров, а также имя сотрудника, 
который осуществлял упаковку заказов (PackedByPersonID).
*/
--Подзапрос
select DISTINCT
	(select c.CityID from application.Cities c where c.CityID=s.DeliveryCityID) as CityID,
	(select c.CityName from application.Cities c where c.CityID=s.DeliveryCityID) as CityName,
	(select ap.FullName from Application.people ap where ap.PersonID=i.PackedByPersonID) as PackPersonName
from sales.Invoices i
	inner join sales.Orders o on o.OrderID=i.OrderID
	inner join sales.OrderLines ol on ol.OrderID=o.OrderID
	inner join sales.Customers s on s.CustomerID=i.CustomerID
where ol.StockItemID in (select top(3) si.StockItemID from Warehouse.StockItems si order by si.UnitPrice desc)
order by CityID;
--CTE
WITH StockItemCTE as 
	(select top(3) StockItemID 
	from Warehouse.StockItems
	order by UnitPrice desc)
select DISTINCT
	(select c.CityID from application.Cities c where c.CityID=s.DeliveryCityID) as CityID,
	(select c.CityName from application.Cities c where c.CityID=s.DeliveryCityID) as CityName,
	(select ap.FullName from Application.people ap where ap.PersonID=i.PackedByPersonID) as PackPersonName
from sales.Invoices i
	inner join sales.Orders o on o.OrderID=i.OrderID
	inner join sales.OrderLines ol on ol.OrderID=o.OrderID
	inner join sales.Customers s on s.CustomerID=i.CustomerID
	where ol.StockItemID in (select * from StockItemCTE)
order by CityID;

-- ---------------------------------------------------------------------------
-- Опциональное задание
-- ---------------------------------------------------------------------------
-- Можно двигаться как в сторону улучшения читабельности запроса, 
-- так и в сторону упрощения плана\ускорения. 
-- Сравнить производительность запросов можно через SET STATISTICS IO, TIME ON. 
-- Если знакомы с планами запросов, то используйте их (тогда к решению также приложите планы). 
-- Напишите ваши рассуждения по поводу оптимизации. 

-- 5. Объясните, что делает и оптимизируйте запрос

set statistics time on
go
SELECT 
	Invoices.InvoiceID, 
	Invoices.InvoiceDate,
	(SELECT People.FullName
		FROM Application.People
		WHERE People.PersonID = Invoices.SalespersonPersonID
	) AS SalesPersonName,
	SalesTotals.TotalSumm AS TotalSummByInvoice, 
	(SELECT SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice)
		FROM Sales.OrderLines
		WHERE OrderLines.OrderId = (SELECT Orders.OrderId 
			FROM Sales.Orders
			WHERE Orders.PickingCompletedWhen IS NOT NULL	
				AND Orders.OrderId = Invoices.OrderId)	
	) AS TotalSummForPickedItems
FROM Sales.Invoices 
	JOIN
	(SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
	FROM Sales.InvoiceLines
	GROUP BY InvoiceId
	HAVING SUM(Quantity*UnitPrice) > 27000) AS SalesTotals
		ON Invoices.InvoiceID = SalesTotals.InvoiceID
ORDER BY TotalSumm DESC
go
set statistics time off
go
-- Время ЦП = 32 мс, затраченное время = 46 мс.


--напишите здесь свое решение
/*
Что делает запрос: 
Отражает номер инвойса, дату инвойса, продавца, стоимость инвойса за вычетом налога и стоимость заказов за вычетом налога.
Основной фильтр по инвойсам с стоимостью за вычетом налога более 2700.
Сумма заказов также рассчитывается с фильтрацией только по сформированным заказам.
Как итог - можно сказать, что запрос отражает информацию по дорогим инвойсам и сопоставляют её с суммой готовых заказов

Оптимизация:
С точки зрения читабельности обернул суммы инвойсов и заказов в отдельные CTEшки, пользовался джойнами, чтобы не писать монструозные подзапросы.
С точки зрения оптимизации строил запрос сразу от инвойсов отфильтрованных по сумме > 2700.
Время ЦП удалось сократить в 2 раза, затраченное время в 1,4
*/

set statistics time on
go
WITH SalesTotalsCTE AS 
	(SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
	FROM Sales.InvoiceLines
	GROUP BY InvoiceId
	HAVING SUM(Quantity*UnitPrice) > 27000),
PickedTotalsCTE AS
	(SELECT OrderLines.OrderID, SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice) as TotalSummForPickedItems
		FROM Sales.OrderLines
		inner join Sales.Orders on orders.OrderID=OrderLines.OrderID
		WHERE Orders.PickingCompletedWhen IS NOT NULL
		GROUP BY OrderLines.OrderID
	)
select SalesTotalsCTE.InvoiceID, 
		Invoices.InvoiceDate, 
		(SELECT People.FullName
			FROM Application.People
			WHERE People.PersonID = Invoices.SalespersonPersonID) AS SalesPersonName,
		SalesTotalsCTE.TotalSumm as TotalSummByInvoice, 
		PickedTotalsCTE.TotalSummForPickedItems
from SalesTotalsCTE
left join sales.Invoices on SalesTotalsCTE.InvoiceID=invoices.InvoiceID
left join PickedTotalsCTE on PickedTotalsCTE.OrderID=Invoices.OrderID
ORDER BY SalesTotalsCTE.TotalSumm DESC
go
set statistics time off
go
-- Время ЦП = 16 мс, затраченное время = 32 мс.