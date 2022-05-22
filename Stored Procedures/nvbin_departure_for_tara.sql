USE [MAX101srl]
GO
/****** Object:  StoredProcedure [dbo].[nvbin_departure_for_tara]    Script Date: 13.05.2022 17:25:32 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec [dbo].[nvbin_departure_for_tara] 'TS00099'
ALTER PROCEDURE [dbo].[nvbin_departure_for_tara]   
    @tara_GUID varchar(100)   
AS   

    SET NOCOUNT ON;  
select	nvbin_CASSIOLI_departure
		from dbo.imsul_pack
		inner join maxmast.nvbin on imsul_pack.ip_nvbin_id = nvbin.nvbin_id
		inner join container_pin_list on imsul_pack.ip_id = container_pin_list.id
		inner join maxmast.nvsto on nvsto_id = nvbin_store_id
	where container_pin_list.serial_number = @tara_GUID



