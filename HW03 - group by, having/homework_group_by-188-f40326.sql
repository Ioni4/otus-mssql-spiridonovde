/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "02 - Оператор SELECT и простые фильтры, GROUP BY, HAVING".

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
1. Посчитать среднюю цену товара, общую сумму продажи по месяцам.
Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Средняя цена за месяц по всем товарам
* Общая сумма продаж за месяц

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select year(i.InvoiceDate) as year, month(i.InvoiceDate) as month, avg(il.unitprice) as avgprice, sum(il.ExtendedPrice) as sumrevenue 
from sales.Invoices i
left join sales.InvoiceLines il on i.InvoiceID=il.InvoiceID
group by year(i.InvoiceDate), month(i.InvoiceDate)
order by year(i.InvoiceDate), month(i.InvoiceDate)

/*
2. Отобразить все месяцы, где общая сумма продаж превысила 4 600 000

Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Общая сумма продаж

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select year(i.InvoiceDate) as year, month(i.InvoiceDate) as month, sum(il.ExtendedPrice) as sumrevenue 
from sales.Invoices i
left join sales.InvoiceLines il on i.InvoiceID=il.InvoiceID
group by year(i.InvoiceDate), month(i.InvoiceDate)
having sum(il.ExtendedPrice) >4600000
order by year(i.InvoiceDate), month(i.InvoiceDate)

/*
3. Вывести сумму продаж, дату первой продажи
и количество проданного по месяцам, по товарам,
продажи которых менее 50 ед в месяц.
Группировка должна быть по году,  месяцу, товару.

Вывести:
* Год продажи
* Месяц продажи
* Наименование товара
* Сумма продаж
* Дата первой продажи
* Количество проданного

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select year(i.InvoiceDate) as year, month(i.InvoiceDate) as month,  si.StockItemName, sum(il.ExtendedPrice) as sumrevenue, min(i.invoicedate) as firstsaledate, sum(il.quantity) as quant 
from sales.Invoices i
left join sales.InvoiceLines il on i.InvoiceID=il.InvoiceID
left join Warehouse.StockItems si on il.StockItemID=si.StockItemID
group by year(i.InvoiceDate), month(i.InvoiceDate), si.StockItemName
having sum(il.quantity) <50
order by year(i.InvoiceDate), month(i.InvoiceDate), si.StockItemName

-- ---------------------------------------------------------------------------
-- Опционально
-- ---------------------------------------------------------------------------
/*
Написать запросы 2-3 так, чтобы если в каком-то месяце не было продаж,
то этот месяц также отображался бы в результатах, но там были нули.
*/

--задание 2
select year(i.InvoiceDate) as year, month(i.InvoiceDate) as month,
case when sum(il.ExtendedPrice)>4600000 then sum(il.ExtendedPrice) else 0 end as sumrevenue 
from sales.Invoices i
left join sales.InvoiceLines il on il.InvoiceID=i.InvoiceID
group by year(i.InvoiceDate), month(i.InvoiceDate)
order by year(i.InvoiceDate), month(i.InvoiceDate)

--задание 3 (предполагаю есть способ проще, но как вариант)
select year(i.InvoiceDate) as year, month(i.InvoiceDate) as month,  si.StockItemName, sum(il.ExtendedPrice) as sumrevenue, min(i.invoicedate) as firstsaledate, sum(il.quantity) as quant 
from sales.Invoices i
left join sales.InvoiceLines il on i.InvoiceID=il.InvoiceID
left join Warehouse.StockItems si on il.StockItemID=si.StockItemID
group by year(i.InvoiceDate), month(i.InvoiceDate), si.StockItemName
having sum(il.quantity) <50
union all
select year(i.InvoiceDate) as year, month(i.InvoiceDate) as month,  si.StockItemName, NULL as sumrevenue, NULL as firstsaledate, NULL as quant 
from sales.Invoices i
left join sales.InvoiceLines il on i.InvoiceID=il.InvoiceID
left join Warehouse.StockItems si on il.StockItemID=si.StockItemID
group by year(i.InvoiceDate), month(i.InvoiceDate), si.StockItemName
having sum(il.quantity) >50
order by year(i.InvoiceDate), month(i.InvoiceDate), si.StockItemName