USE [MAX101srl]
GO
/****** Object:  StoredProcedure [dbo].[correct_placement_of_package]    Script Date: 13.05.2022 17:22:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec [dbo].[correct_placement_of_package] '15CC86AF-088E-4900-BBD3-59FE9EC1A628' 'F23E2FEF-9868-43C2-BA5F-1672EF9C7097'
ALTER PROCEDURE [dbo].[correct_placement_of_package]  
    @storage_GUID uniqueidentifier,   
    @package_GUID varchar(100)   
AS   

    SET NOCOUNT ON;  
select	nvsto_store as nvsto_store,
		nvbin_room as nvbin_room,
		nvbin_bin as nvbin_bin
		from maxmast.pu00_packages
		inner join maxmast.nvbin on pu00_packages.nvbin_id = nvbin.nvbin_id
		inner join maxmast.nvsto on nvsto_id = nvbin_store_id
		inner join maxmast.pu00_cargo_type on pu00_cargo_type.id = pu00_packages.cargo_type_id
	where nvbin_GUID = @storage_GUID and pu00_packages.id = @package_GUID



