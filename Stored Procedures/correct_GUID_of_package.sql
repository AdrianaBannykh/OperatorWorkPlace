USE [MAX101srl]
GO
/****** Object:  StoredProcedure [dbo].[correct_GUID_of_package]    Script Date: 13.05.2022 18:07:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[correct_GUID_of_package]   
    @package_GUID varchar(100)   
AS   

    SET NOCOUNT ON;  
select	pu00_packages.id
		from maxmast.pu00_packages
	where pu00_packages.id = @package_GUID


