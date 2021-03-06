USE [MAX101srl]
GO
/****** Object:  StoredProcedure [dbo].[pin_information]    Script Date: 13.05.2022 18:04:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec [dbo].[pin_information] 'f77e94ae-0900-4f95-83af-f5b08de2c308'
ALTER PROCEDURE [dbo].[pin_information]   
    @pin_code varchar(100)   
AS   

    SET NOCOUNT ON;  
select imsu_serno as imsu_serno,
		imsu_balance as imsu_balance,
		imast_item as imast_item,
		imast_descext as imast_descext
		from dbo.imsul_pack
			inner join dbo.container_pin_list on container_pin_list.serial_number = ip_pack 
			inner join maxmast.imsu on ip_imsu_id = imsu_id
			inner join maxmast.imast on imsu_item_id = imast_id
		where pin_code = @pin_code


