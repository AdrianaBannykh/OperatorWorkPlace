USE [MAX101srl]
GO
/****** Object:  StoredProcedure [dbo].[correct_placement_of_containers]    Script Date: 13.05.2022 17:18:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec [dbo].[correct_placement_of_containers] 'C1F997BF-B3C6-4C41-81E9-A547EF21C0B6' 'TS00099'
ALTER PROCEDURE [dbo].[correct_placement_of_containers]  
    @storage_GUID uniqueidentifier,   
    @tara_GUID varchar(100)   
AS   

    SET NOCOUNT ON;  
    select	container_pin_list.serial_number as serial_number,
		nvbin_GUID as nvbin_GUID,
		nvsto_store as nvsto_store,
		nvbin_room as nvbin_room,
		nvbin_bin as nvbin_bin
		from dbo.imsul_pack
		inner join maxmast.nvbin on imsul_pack.ip_nvbin_id = nvbin.nvbin_id
		inner join container_pin_list on imsul_pack.ip_id = container_pin_list.id
		inner join maxmast.nvsto on nvsto_id = nvbin_store_id
	where nvbin_GUID = @storage_GUID and container_pin_list.serial_number = @tara_GUID


