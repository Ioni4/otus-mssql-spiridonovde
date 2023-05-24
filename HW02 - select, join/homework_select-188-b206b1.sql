/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "02 - Оператор SELECT и простые фильтры, JOIN".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД WideWorldImporters можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Все товары, в названии которых есть "urgent" или название начинается с "Animal".
Вывести: ИД товара (StockItemID), наименование товара (StockItemName).
Таблицы: Warehouse.StockItems.
*/

select StockItemID, StockItemName 
from Warehouse.StockItems
where StockItemName like '%urgent%' or StockItemName like 'Animal%'

/*
2. Поставщиков (Suppliers), у которых не было сделано ни одного заказа (PurchaseOrders).
Сделать через JOIN, с подзапросом задание принято не будет.
Вывести: ИД поставщика (SupplierID), наименование поставщика (SupplierName).
Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders.
По каким колонкам делать JOIN подумайте самостоятельно.
*/

select s.SupplierID, s.SupplierName 
from Purchasing.Suppliers s
left join Purchasing.PurchaseOrders p on p.SupplierID=s.SupplierID
where p.SupplierID is null

/*
3. Заказы (Orders) с ценой товара (UnitPrice) более 100$ 
либо количеством единиц (Quantity) товара более 20 штук
и присутствующей датой комплектации всего заказа (PickingCompletedWhen).
Вывести:
* OrderID
* дату заказа (OrderDate) в формате ДД.ММ.ГГГГ
* название месяца, в котором был сделан заказ
* номер квартала, в котором был сделан заказ
* треть года, к которой относится дата заказа (каждая треть по 4 месяца)
* имя заказчика (Customer)
*/
select distinct o.orderID, orderdate, DATENAME(MONTH, orderdate) as MName, DATEPART(QUARTER, orderdate) as QNumber, (DATEPART(MONTH, orderdate)-1)/4+1 as TrimNumber, c.CustomerName
from sales.Orders o 
inner join sales.OrderLines ol on o.OrderID=ol.OrderID
left join sales.Customers c on o.CustomerID=c.CustomerID
where ol.quantity>20 or (ol.unitprice>100 and ol.PickingCompletedWhen is not null)

/*Добавьте вариант этого запроса с постраничной выборкой,
пропустив первую 1000 и отобразив следующие 100 записей.

Сортировка должна быть по номеру квартала, трети года, дате заказа (везде по возрастанию).

Таблицы: Sales.Orders, Sales.OrderLines, Sales.Customers.
*/
select distinct o.orderID, orderdate, DATENAME(MONTH, orderdate) as MName, DATEPART(QUARTER, orderdate) as QNumber, (DATEPART(MONTH, orderdate)-1)/4+1 as TrimNumber, c.CustomerName
from sales.Orders o 
inner join sales.OrderLines ol on o.OrderID=ol.OrderID
left join sales.Customers c on o.CustomerID=c.CustomerID
where ol.quantity>20 or (ol.unitprice>100 and ol.PickingCompletedWhen is not null)
order by QNumber, TrimNumber, OrderDate
offset 1000 rows
fetch first 100 rows only

/*
4. Заказы поставщикам (Purchasing.Suppliers),
которые должны быть исполнены (ExpectedDeliveryDate) в январе 2013 года
с доставкой "Air Freight" или "Refrigerated Air Freight" (DeliveryMethodName)
и которые исполнены (IsOrderFinalized).
Вывести:
* способ доставки (DeliveryMethodName)
* дата доставки (ExpectedDeliveryDate)
* имя поставщика
* имя контактного лица принимавшего заказ (ContactPerson)

Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders, Application.DeliveryMethods, Application.People.
*/

select po.PurchaseOrderID, d.DeliveryMethodName, po.ExpectedDeliveryDate, s.SupplierName, p.PreferredName as ContactPerson 
from Purchasing.PurchaseOrders po
inner join Purchasing.Suppliers s on s.SupplierID=po.SupplierID
inner join Application.DeliveryMethods d on d.DeliveryMethodID=po.DeliveryMethodID
inner join Application.People p on p.PersonID=po.ContactPersonID
where po.ExpectedDeliveryDate between '2013-01-01' and '2013-01-31' and d.DeliveryMethodName in ('Air Freight', 'Refrigerated Air Freight')

/*
5. Десять последних продаж (по дате продажи) с именем клиента и именем сотрудника,
который оформил заказ (SalespersonPerson).
Сделать без подзапросов.
*/

select top 10 o.OrderID, o.OrderDate, c.CustomerName, p.FullName as SalespersonPerson 
from sales.Orders o
left join sales.Customers c on c.CustomerID=o.CustomerID
left join Application.People p on p.PersonID=o.SalespersonPersonID
order by OrderDate desc

/*
6. Все ид и имена клиентов и их контактные телефоны,
которые покупали товар "Chocolate frogs 250g".
Имя товара смотреть в таблице Warehouse.StockItems.
*/

select distinct o.CustomerID, c.CustomerName, c.PhoneNumber from sales.Orders o
inner join sales.OrderLines ol on ol.OrderID=o.OrderID
inner join Warehouse.StockItems si on si.StockItemID=ol.StockItemID
inner join sales.Customers c on c.CustomerID=o.CustomerID
where si.StockItemName = 'Chocolate frogs 250g'

