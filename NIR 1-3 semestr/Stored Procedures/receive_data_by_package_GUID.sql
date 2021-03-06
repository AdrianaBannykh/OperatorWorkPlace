USE [MAX101srl]
GO
/****** Object:  StoredProcedure [dbo].[receive_data_by_package_GUID]    Script Date: 13.05.2022 17:08:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec [dbo].[receive_data_by_package_GUID] '82334AAA-CC6B-4149-A5AA-00E6A5CA0623'
ALTER PROCEDURE [dbo].[receive_data_by_package_GUID]
		@package_GUID uniqueidentifier
AS
BEGIN
--Запрос получения данных по идентификатору грузового места. (declare @package_GUID uniqueidentifier = '82334AAA-CC6B-4149-A5AA-00E6A5CA0623')
--На вход принимает идентификатор грузового места (package_GUID)
--Возвращает поля:
--Номер заказа на закупку (puord_orderno) - в одном грузовом месте может быть несколько заказов на закупку(то есть в одной большой коробке несколько коробок)
--Дата доставки (pu00_delivery.date_delivery) - когда пришло грузовое место
--Откуда пришло (puord_supplier_id) - откуда пришло, то есть от какого поставщика
--Исполнитель (pu00_delivery.executor_id) - кто разгружал
--Дата получения (received_date) - когда разружал
--Данные о фактической поставке - номер ИПТ (pugrn_grn), дата, когда была выполнена поставка (pugrn_grndate), количество товаров в единицах поставки заказа, поступившее от поставщика в пункт приёмки(pugrn_qtygood)
--Данные приёмочного контроля - количество товаров в единицах поставки заказа, поступившее от поставщика в пункт приёмки (pugrn_qtyinsp), количество товаров в единицах поставки заказа, возвращенное поставшику из пункта приёмки (pugrn_qtyreturn)
	select puord_orderno as puord_orderno,
			pu00_delivery.date_delivery as date_delivery,
			puord_supplier_id as puord_supplier_id,
			pu00_delivery.executor_id as executor_id,
			received_date as received_date,
			pugrn_grn as pugrn_orderno,
			pugrn_grndate as pugrn_grndate,
			pugrn_qtygood as pugrn_qtygood,
			pugrn_qtyinsp as qtyinsp,
			pugrn_qtyreturn as pugrn_qtyreturn
			from maxmast.pu00_delivery
			inner join maxmast.pu00_packages on delivery_id = pu00_delivery.id
			inner join maxmast.pu00_delivery_composition on pu00_delivery_composition.delivery_id = pu00_delivery.id
			inner join maxmast.puord on puord.puord_id = pu00_delivery_composition.puord_id
			inner join maxmast.pulin on pulin_puord_id = puord.puord_id
			inner join maxmast.purel on purel_pulin_id = pulin.pulin_id
			inner join maxmast.pugrn on pugrn_purel_id = purel_id
			inner join maxmast.imast on pulin_item_id = imast_id
		where pu00_packages.id = @package_GUID
END