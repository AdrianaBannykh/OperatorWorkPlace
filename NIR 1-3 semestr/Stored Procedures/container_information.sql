USE [MAX101srl]
GO
/****** Object:  StoredProcedure [dbo].[container_information]    Script Date: 13.05.2022 18:00:33 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec [dbo].[container_information] 'TS00103'
ALTER PROCEDURE [dbo].[container_information]   
    @tara_GUID varchar(100)   
AS   

    SET NOCOUNT ON;  
select DISTINCT
			imsu_serno,
			imast_item,
			cell_name,
			ip_balance,
			puord_orderno,
			mfop_opno,
			mfop_shortdesc
		from maxmast.imsul
			inner join maxmast.imsu	on imsu_id = imsul_imsu_id
			inner join maxmast.imast on imast_id = imsu_item_id
			inner join maxmast.nvacc on nvacc_id = imsul_nvacc_id
			inner join maxmast.nvsto on nvsto_id = imsul_store_id
			inner join maxmast.nvbin	on imsul_nvbin_id = nvbin_id
			inner join maxmast.pugrn on pugrn_serno_id = imsu_id
			inner join maxmast.purel on pugrn_purel_id = purel_id
			inner join maxmast.pulin on purel_pulin_id = pulin_id
			inner join maxmast.puord on pulin_puord_id = puord_id 
			inner join maxmast.mford on mford_id = imast_id
			inner join maxmast.mfop on mford_id=mfop_orderno_id
			inner join maxmast.mftrn on mfop_id=mftrn_opno_id
			inner join dbo.imsul_pack on ip_imsul_id = imsul_id
			inner join dbo.container_pin_list on container_pin_list.serial_number = ip_pack 
		where dbo.container_pin_list.serial_number = @tara_GUID and mfop_status = 'F'





