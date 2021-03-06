USE [MAX101srl]
GO
/****** Object:  StoredProcedure [dbo].[container_contents]    Script Date: 13.05.2022 17:29:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec [dbo].[container_contents] 'TS00099'
ALTER PROCEDURE [dbo].[container_contents]   
    @tara_GUID varchar(100)   
AS   

    SET NOCOUNT ON;  
select 	imsu_serno as imsul_serno,
			imast_item as imast_item,
			cell_name as cell_name,
			ip_balance
		from maxmast.imsul
			inner join maxmast.imsu	on imsu_id = imsul_imsu_id
			inner join maxmast.imast on imast_id = imsu_item_id
			inner join maxmast.nvacc on nvacc_id = imsul_nvacc_id
			inner join maxmast.nvsto on nvsto_id = imsul_store_id
			inner join maxmast.nvbin	on imsul_nvbin_id = nvbin_id
			inner join dbo.imsul_pack on ip_imsul_id = imsul_id
			inner join dbo.container_pin_list on container_pin_list.serial_number = ip_pack 
		where dbo.container_pin_list.serial_number = @tara_GUID
		order by cell_name




